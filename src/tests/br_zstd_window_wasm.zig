//! Small real public consumers for 32-bit advertised-window and heap policies.
const std = @import("std");
const vort = @import("vort");
const br = vort.br;
const zstd = vort.zstd;
var metrics: [13]u64 = @splat(0);

export fn windowMetric(index: u32) callconv(.c) u64 {
    if (index == 0) return @bitSizeOf(usize);
    return if (index < metrics.len) metrics[index] else 0;
}

export fn windowBrotliSmoke() callconv(.c) u32 {
    const a = std.heap.page_allocator;
    const input = "abcdefghabcdefghXabcdefgh tail!\n" ** 4;
    inline for (.{ @as(u4, 0), @as(u4, 4) }, 0..) |quality, index| {
        const width: u5 = if (quality == 0) 16 else 30;
        var memory: br.EncodeMemoryProfile = .{};
        var options: br.PlannedEncodeOptions = .{ .quality = quality, .window_bits = width, .large_window = true, .memory_profile = &memory };
        const wire = br.encodePlannedStreamWithOptionsAlloc(a, input, options) catch return 1;
        defer a.free(wire);
        if (wire.len < 2 or wire[0] != 0x11 or (wire[1] & 63) != width) return 2;
        if (br.decodeStreamAllocExactSize(a, wire, input.len)) |unexpected| {
            a.free(unexpected);
            return 3;
        } else |err| if (err != error.CorruptFrame) return 4;
        const decoded = br.decodeStreamAllocExactSizeWithOptions(a, wire, input.len, .{ .allow_large_window = true }) catch return 5;
        defer a.free(decoded);
        if (!std.mem.eql(u8, input, decoded)) return 6;
        if (!memory.available or memory.peak_requested_bytes == 0 or memory.live_requested_bytes != 0) return 7;
        const peak = memory.peak_requested_bytes;
        metrics[1 + index * 2] = width;
        metrics[2 + index * 2] = peak;
        memory.reset();
        options.max_total_working_memory = peak;
        const exact = br.encodePlannedStreamWithOptionsAlloc(a, input, options) catch return 8;
        defer a.free(exact);
        if (!std.mem.eql(u8, wire, exact) or memory.peak_requested_bytes != peak or memory.live_requested_bytes != 0) return 9;
        for ([_]usize{ 0, peak - 1 }) |limit| {
            memory.reset();
            options.max_total_working_memory = limit;
            if (br.encodePlannedStreamWithOptionsAlloc(a, input, options)) |unexpected| {
                a.free(unexpected);
                return 10;
            } else |err| if (err != error.WorkingMemoryLimitExceeded) return 11;
            if (memory.live_requested_bytes != 0 or memory.peak_requested_bytes > limit) return 12;
        }
    }
    return 0;
}

export fn windowZstdSmoke() callconv(.c) u32 {
    const a = std.heap.page_allocator;
    const input = "zstd-window-41!\n" ** 32;
    var memory: zstd.EncodeMemoryProfile = .{};
    var controls: zstd.EncoderControlProfile = .{};
    var options: zstd.NativeFrameOptions = .{
        .include_content_size = false,
        .window_log = 41,
        .max_match_history_len = 128 * 1024 * 1024,
        .strategy = .fast,
        .control_profile = &controls,
        .memory_profile = &memory,
    };
    const encoded = zstd.encodeNativeFrameWithOptionsAlloc(a, input, options) catch return 101;
    defer a.free(encoded.frame);
    const header = zstd.inspectNativeFrameHeader(encoded.frame) catch return 102;
    if (header.window_size != @as(u64, 1) << 41 or header.content_size != null) return 103;
    if (controls.requested_window_size != @as(?u64, @as(u64, 1) << 41) or controls.effective_match_history_len != 128 * 1024 * 1024) return 104;
    if (!memory.available or memory.live_requested_bytes != 0 or memory.peak_requested_bytes == 0 or memory.peak_requested_bytes >= 16 * 1024 * 1024) return 105;
    const decoded = zstd.decodeNativeFrameAllocExactSize(a, encoded.frame, input.len) catch return 106;
    defer a.free(decoded);
    if (!std.mem.eql(u8, input, decoded)) return 107;
    const peak = memory.peak_requested_bytes;
    metrics[5] = header.window_size;
    metrics[6] = controls.effective_match_history_len;
    metrics[7] = peak;
    metrics[8] = memory.live_requested_bytes;
    memory.reset();
    controls.reset();
    options.max_total_working_memory = peak;
    const exact = zstd.encodeNativeFrameWithOptionsAlloc(a, input, options) catch return 108;
    defer a.free(exact.frame);
    if (!std.mem.eql(u8, encoded.frame, exact.frame) or memory.peak_requested_bytes != peak or memory.live_requested_bytes != 0) return 109;
    for ([_]usize{ 0, peak - 1 }) |limit| {
        memory.reset();
        controls.reset();
        options.max_total_working_memory = limit;
        if (zstd.encodeNativeFrameWithOptionsAlloc(a, input, options)) |unexpected| {
            a.free(unexpected.frame);
            return 110;
        } else |err| if (err != error.WorkingMemoryLimitExceeded) return 111;
        if (memory.live_requested_bytes != 0 or memory.peak_requested_bytes > limit) return 112;
    }
    return 0;
}

export fn windowZstdRawSmoke() callconv(.c) u32 {
    const a = std.heap.page_allocator;
    const input = "raw-or-rle-41!\n" ** 32;
    var memory: zstd.EncodeMemoryProfile = .{};
    var encoder = zstd.NativeIncrementalFrameEncoder.init(a, .{
        .include_content_size = false,
        .window_log = 41,
        .max_match_history_len = 128 * 1024 * 1024,
        .selection = .raw_or_rle,
        .memory_profile = &memory,
    }) catch return 201;
    var alive = true;
    defer if (alive) encoder.deinit();
    var wire: std.ArrayList(u8) = .empty;
    defer wire.deinit(a);
    var output: [37]u8 = undefined;
    var offset: usize = 0;
    while (offset != input.len) {
        const step = encoder.step(input[offset..@min(input.len, offset + 17)], &output) catch return 202;
        offset += step.progress.input_read;
        wire.appendSlice(a, output[0..step.progress.output_written]) catch return 203;
        if (step.progress.input_read == 0 and step.progress.output_written == 0) return 204;
    }
    encoder.finish();
    while (true) {
        const step = encoder.step("", &output) catch return 205;
        wire.appendSlice(a, output[0..step.progress.output_written]) catch return 206;
        if (step.status == .done) break;
        if (step.progress.output_written == 0) return 207;
    }
    if (encoder.history.bytes.items.len != 0 or encoder.history.bytes.capacity != 0) return 208;
    const header = zstd.inspectNativeFrameHeader(wire.items) catch return 209;
    if (header.window_size != @as(u64, 1) << 41 or header.content_size != null) return 210;
    metrics[9] = encoder.history.bytes.capacity;
    metrics[12] = header.window_size;
    encoder.deinit();
    alive = false;
    if (!memory.available or memory.live_requested_bytes != 0 or memory.peak_requested_bytes == 0 or memory.peak_requested_bytes >= 1024 * 1024) return 211;
    metrics[10] = memory.peak_requested_bytes;
    metrics[11] = memory.live_requested_bytes;
    const decoded = zstd.decodeNativeFrameAllocExactSize(a, wire.items, input.len) catch return 212;
    defer a.free(decoded);
    if (!std.mem.eql(u8, input, decoded)) return 213;
    return 0;
}
