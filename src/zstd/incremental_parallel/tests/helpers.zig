//! Independent wire inspection and caller-owned buffers for the public tests.
const std = @import("std");
const core = @import("../../../core.zig");
const types = @import("../types.zig");
const previous = @import("../../parallel/tests/helpers.zig");

pub const a = std.testing.allocator;
pub const Count = core.StreamCount;
pub const Heap = previous.Heap;
pub const noise = previous.noise;
pub const full_dictionary = previous.full_dictionary;
pub const untouched = previous.untouched;

pub fn options(comptime Z: type) types.EncoderOptions(Z.NativeFrameOptions) {
    return .{
        .frame = .{ .include_content_size = false, .window_log = 10, .block_size_max = 128 },
        .parallel = .{ .io = std.testing.io, .worker_count = 2, .job_size = 256, .max_inflight_jobs = 4, .max_inflight_bytes = 1024, .max_working_memory = 64 * 1024 * 1024 },
    };
}

pub fn fixture(comptime len: usize) [len]u8 {
    var bytes: [len]u8 = undefined;
    const text = "{\"service\":\"vort\",\"items\":[1,4,8],\"status\":\"repeated\"}\n";
    for (&bytes, 0..) |*byte, i| byte.* = if (i % 97 == 0) @truncate(i / 97) else text[i % text.len];
    return bytes;
}

pub fn bounds(snapshot: anytype, opts: anytype) !void {
    const q = snapshot.parallel;
    const p = q.profile;
    try std.testing.expect(q.inflight_jobs <= opts.parallel.max_inflight_jobs);
    try std.testing.expect(q.inflight_bytes <= opts.parallel.max_inflight_bytes);
    try std.testing.expect(q.partial_input_bytes <= q.inflight_bytes);
    try std.testing.expect(p.delivered_jobs <= p.published_jobs);
    try std.testing.expect(p.published_jobs <= p.encoded_jobs);
    try std.testing.expect(p.encoded_jobs <= p.accepted_jobs);
    try std.testing.expect(p.delivered_blocks <= p.published_blocks);
    try std.testing.expect(p.published_blocks <= p.encoded_blocks);
    try std.testing.expect(p.accepted_input_bytes <= snapshot.frame_input);
    const limit = @min(opts.parallel.max_working_memory, opts.frame.max_total_working_memory orelse std.math.maxInt(usize));
    try std.testing.expect(p.live_requested_bytes <= limit);
    try std.testing.expect(p.peak_requested_bytes <= limit);
}

pub fn checked(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, opts: anytype, input: []const u8, output: []u8) !core.StepResult {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    const step = try encoder.step(input, output);
    const after = encoder.snapshot();
    try std.testing.expect(step.progress.input_read <= input.len and step.progress.output_written <= output.len);
    try std.testing.expectEqual(core.stream_count.fromLocal(step.progress.input_read), after.input_read - before.input_read);
    try std.testing.expectEqual(core.stream_count.fromLocal(step.progress.output_written), after.output_written - before.output_written);
    try std.testing.expectEqual(step.progress, after.parallel.last_step_progress);
    try std.testing.expectEqual(@as(?core.Progress, null), encoder.failedProgress());
    try untouched(output[step.progress.output_written..]);
    try bounds(after, opts);
    return step;
}

pub fn failed(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, input: []const u8, output: []u8, expected: anyerror) !core.Progress {
    @memset(output, 0xa5);
    const before = encoder.snapshot();
    try std.testing.expectError(expected, encoder.step(input, output));
    const after = encoder.snapshot();
    const progress = encoder.failedProgress() orelse return error.TestUnexpectedResult;
    try std.testing.expectEqual(progress, after.parallel.last_step_progress);
    try std.testing.expect(progress.input_read <= input.len and progress.output_written <= output.len);
    try std.testing.expectEqual(core.stream_count.fromLocal(progress.input_read), after.input_read - before.input_read);
    try std.testing.expectEqual(core.stream_count.fromLocal(progress.output_written), after.output_written - before.output_written);
    try untouched(output[progress.output_written..]);
    return progress;
}

pub fn sticky(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, expected: anyerror) !void {
    const before = encoder.snapshot();
    try std.testing.expect(before.parallel.failed);
    try std.testing.expectEqual(@as(usize, 0), before.parallel.profile.workers_live);
    var output: [19]u8 = undefined;
    const progress = try failed(Z, encoder, "unaccepted", &output, expected);
    try std.testing.expectEqual(core.Progress{}, progress);
    const after = encoder.snapshot();
    try std.testing.expectEqual(before.input_read, after.input_read);
    try std.testing.expectEqual(before.output_written, after.output_written);
    try std.testing.expectEqual(@as(?anyerror, expected), after.parallel.last_error);
}

pub fn headerLen(frame: anytype, expected: ?Count, dictionary_id: u32) usize {
    const magic: usize = if (frame.format == .standard) 4 else 0;
    const dictionary: usize = if (dictionary_id == 0) 0 else if (dictionary_id <= 255) 1 else if (dictionary_id <= 65535) 2 else 4;
    const length = expected orelse return magic + 2 + dictionary;
    const single = if (frame.window_log) |log| @as(u64, length) <= (@as(u64, 1) << log) else true;
    const field: usize = if (length <= 255) 1 else if (length <= 65791) 2 else if (length <= std.math.maxInt(u32)) 4 else 8;
    return magic + 1 + @as(usize, if (single) 0 else 1) + dictionary + field;
}

pub fn header(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, opts: anytype, expected: ?Count, encoded: *std.ArrayList(u8)) !void {
    const length = headerLen(opts.frame, expected, opts.frame.dictionary_id);
    for (0..length) |_| {
        var output: [1]u8 = undefined;
        const step = try checked(Z, encoder, opts, "", &output);
        try std.testing.expectEqual(@as(usize, 0), step.progress.input_read);
        try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
    }
}

/// Each offered slice is copied anew and overwritten immediately after step.
/// Only reported input_read is advanced, including calls with output pressure.
pub fn feed(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, opts: anytype, encoded: *std.ArrayList(u8), input: []const u8, input_quota: usize, output_quota: usize) !void {
    try std.testing.expect(input_quota != 0 and input_quota <= 257 and output_quota != 0 and output_quota <= 257);
    var offset: usize = 0;
    for (0..input.len * 32 + 16384) |_| {
        var borrowed: [257]u8 = undefined;
        const len = @min(input_quota, input.len - offset);
        @memcpy(borrowed[0..len], input[offset..][0..len]);
        var output: [257]u8 = undefined;
        const step = try checked(Z, encoder, opts, borrowed[0..len], output[0..output_quota]);
        @memset(&borrowed, 0xdd);
        offset += step.progress.input_read;
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (offset == input.len and step.status == .need_input) return;
        try std.testing.expect(step.status != .done);
    }
    return error.TestUnexpectedResult;
}

pub fn drain(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, opts: anytype, encoded: *std.ArrayList(u8), expected: core.StepResult.Status, output_quota: usize) !void {
    try std.testing.expect(output_quota != 0 and output_quota <= 257);
    for (0..1024 * 1024) |_| {
        var output: [257]u8 = undefined;
        const step = try checked(Z, encoder, opts, "", output[0..output_quota]);
        try encoded.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == expected) return;
        try std.testing.expectEqual(core.StepResult.Status.need_output, step.status);
    }
    return error.TestUnexpectedResult;
}

pub fn drive(comptime Z: type, encoder: *Z.NativeIncrementalParallelFrameEncoder, opts: anytype, input: []const u8, input_quota: usize, output_quota: usize) ![]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    errdefer encoded.deinit(a);
    try feed(Z, encoder, opts, &encoded, input, input_quota, output_quota);
    encoder.finish();
    try drain(Z, encoder, opts, &encoded, .done, output_quota);
    return encoded.toOwnedSlice(a);
}

fn integer(bytes: []const u8, cursor: *usize, size: usize) !u64 {
    try std.testing.expect(size <= 8 and cursor.* <= bytes.len and size <= bytes.len - cursor.*);
    var result: u64 = 0;
    for (bytes[cursor.*..][0..size], 0..) |byte, i| result |= @as(u64, byte) << @intCast(i * 8);
    cursor.* += size;
    return result;
}

pub const Summary = struct {
    header_len: usize = 0,
    blocks: usize = 0,
    raw: usize = 0,
    rle: usize = 0,
    compressed: usize = 0,
    max_payload_size: usize = 0,
    last_payload_size: usize = 0,
    checksum_offset: usize = 0,
    window_size: u64 = 0,
};

/// RFC frame fields and physical block exhaustion, independent of vort parsers.
pub fn envelope(comptime Z: type, bytes: []const u8, input: []const u8, frame: Z.NativeFrameOptions, dictionary_id: u32) !Summary {
    var cursor: usize = 0;
    if (frame.format == .standard) try std.testing.expectEqual(@as(u64, 0xfd2fb528), try integer(bytes, &cursor, 4));
    const descriptor = try integer(bytes, &cursor, 1);
    try std.testing.expect(descriptor & 0x18 == 0);
    try std.testing.expectEqual(frame.content_checksum, descriptor & 4 != 0);
    const single = descriptor & 0x20 != 0;
    var result: Summary = .{};
    if (!single) {
        const window = try integer(bytes, &cursor, 1);
        const base = @as(u64, 1) << @as(u6, @intCast(10 + (window >> 3)));
        result.window_size = base + (base / 8) * (window & 7);
    }
    const dictionary_size: usize = switch (descriptor & 3) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    try std.testing.expectEqual(@as(u64, dictionary_id), try integer(bytes, &cursor, dictionary_size));
    const size_flag = descriptor >> 6;
    const size_bytes: usize = switch (size_flag) {
        0 => if (single) 1 else 0,
        1 => 2,
        2 => 4,
        else => 8,
    };
    const stored = try integer(bytes, &cursor, size_bytes);
    if (frame.include_content_size) {
        try std.testing.expect(size_bytes != 0);
        const actual = stored + @as(u64, if (size_flag == 1) 256 else 0);
        try std.testing.expectEqual(@as(u64, input.len), actual);
        if (single) result.window_size = actual;
    } else try std.testing.expectEqual(@as(usize, 0), size_bytes);
    result.header_len = cursor;
    while (true) {
        const block = try integer(bytes, &cursor, 3);
        const kind = (block >> 1) & 3;
        const size: usize = @intCast(block >> 3);
        try std.testing.expect(kind != 3 and size <= std.compress.zstd.block_size_max);
        result.blocks += 1;
        result.max_payload_size = @max(result.max_payload_size, size);
        switch (kind) {
            0 => result.raw += 1,
            1 => result.rle += 1,
            2 => result.compressed += 1,
            else => unreachable,
        }
        const payload_size = if (kind == 1) @as(usize, 1) else size;
        try std.testing.expect(cursor <= bytes.len and payload_size <= bytes.len - cursor);
        cursor += payload_size;
        if (block & 1 != 0) {
            result.last_payload_size = size;
            break;
        }
    }
    result.checksum_offset = cursor;
    if (frame.content_checksum) try std.testing.expectEqual(@as(u64, @as(u32, @truncate(std.hash.XxHash64.hash(0, input)))), try integer(bytes, &cursor, 4));
    try std.testing.expectEqual(bytes.len, cursor);
    return result;
}

pub fn verify(comptime Z: type, bytes: []const u8, input: []const u8, frame: Z.NativeFrameOptions, dictionary: ?Z.NativeDictionary) !Summary {
    const result = try envelope(Z, bytes, input, frame, if (dictionary) |dict| dict.id else frame.dictionary_id);
    const decoded = try Z.decodeFrameAllocWithOptions(a, bytes, .{ .format = frame.format, .dictionary = dictionary });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    // std's independent implementation has no preset-dictionary route. Such
    // rows retain native content + independent envelope evidence; external
    // dictionary interoperability is a separate reference-tool campaign.
    if (dictionary == null and frame.dictionary_id == 0) {
        const independent = try previous.stdDecode(bytes, frame.format == .magicless);
        defer a.free(independent);
        try std.testing.expectEqualSlices(u8, input, independent);
    }
    return result;
}

pub fn complete(snapshot: anytype, opts: anytype, input_len: usize, blocks: usize) !void {
    try bounds(snapshot, opts);
    const q = snapshot.parallel;
    const p = q.profile;
    try std.testing.expect(snapshot.done and p.enabled);
    try std.testing.expectEqual(core.stream_count.fromLocal(input_len), snapshot.frame_input);
    try std.testing.expectEqual(core.stream_count.fromLocal(input_len), p.accepted_input_bytes);
    try std.testing.expectEqual(p.accepted_jobs, p.encoded_jobs);
    try std.testing.expectEqual(p.encoded_jobs, p.published_jobs);
    try std.testing.expectEqual(p.published_jobs, p.delivered_jobs);
    try std.testing.expectEqual(core.stream_count.fromLocal(blocks), p.delivered_blocks);
    try std.testing.expectEqual(@as(usize, 0), q.inflight_jobs);
    try std.testing.expectEqual(@as(usize, 0), q.inflight_bytes);
    try std.testing.expectEqual(@as(usize, 0), q.owned_input_bytes);
    try std.testing.expectEqual(@as(usize, 0), p.workers_live);
}

pub fn run(comptime Z: type) type {
    return struct {
        test "Zstd parallel incremental typed observations preserve wide counters and local geometry" {
            const E = Z.NativeIncrementalParallelFrameEncoder;
            try std.testing.expect(@FieldType(E.Snapshot, "input_read") == Count);
            try std.testing.expect(@FieldType(E.Snapshot, "output_written") == Count);
            try std.testing.expect(@FieldType(E.Snapshot, "frame_input") == Count);
            try std.testing.expect(@FieldType(E.Snapshot, "frame_output") == Count);
            try std.testing.expect(@FieldType(E.Snapshot, "frame_count") == Count);
            try std.testing.expect(@FieldType(E.Snapshot, "frame_index") == Count);
            try std.testing.expect(@FieldType(types.Profile, "accepted_jobs") == Count);
            try std.testing.expect(@FieldType(types.Profile, "delivered_blocks") == Count);
            try std.testing.expect(@FieldType(types.Snapshot, "inflight_bytes") == usize);
            try std.testing.expect(@FieldType(core.Progress, "input_read") == usize);
            const O = @TypeOf(options(Z));
            try std.testing.expect(@FieldType(O, "max_input_len") == Count);
            try std.testing.expect(@FieldType(O, "max_output_len") == Count);
            try std.testing.expect(@FieldType(O, "max_job_count") == Count);
        }

        test "Zstd parallel incremental declared wide content size emits a bounded header without huge input" {
            var opts = options(Z);
            opts.frame.include_content_size = true;
            const declared: Count = (@as(Count, 1) << 32) + 3;
            var encoder = try Z.NativeIncrementalParallelFrameEncoder.initExactSize(a, opts, declared);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(a);
            try header(Z, &encoder, opts, declared, &bytes);
            try std.testing.expectEqual(@as(usize, 14), bytes.items.len);
            var cursor: usize = 6;
            try std.testing.expectEqual(@as(u64, declared), try integer(bytes.items, &cursor, 8));
            try std.testing.expectEqual(@as(Count, 0), encoder.snapshot().input_read);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.owned_input_bytes);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.profile.workers_started);
        }

        test "Zstd parallel incremental unknown size header keeps the configured legacy window" {
            var opts = options(Z);
            opts.frame.window_log = null;
            var encoder = try Z.NativeIncrementalParallelFrameEncoder.init(a, opts);
            defer encoder.deinit();
            var bytes: std.ArrayList(u8) = .empty;
            defer bytes.deinit(a);
            try header(Z, &encoder, opts, null, &bytes);
            try std.testing.expectEqual(@as(usize, 6), bytes.items.len);
            try std.testing.expect(bytes.items[4] & 0xe0 == 0);
            const descriptor = bytes.items[5];
            const base = @as(u64, 1) << @as(u6, @intCast(10 + (descriptor >> 3)));
            const advertised = base + base / 8 * (descriptor & 7);
            try std.testing.expectEqual(@as(u64, std.compress.zstd.default_window_len), advertised);
            try std.testing.expectEqual(@as(usize, 0), encoder.snapshot().parallel.owned_input_bytes);
        }

        test "Zstd parallel incremental wide job ceilings round only local bounded geometry" {
            var parallel = options(Z).parallel;
            parallel.job_size = 129;
            parallel.max_inflight_bytes = 1024;
            const wide: Count = (@as(Count, 1) << 32) + 3;
            const geometry = try types.Geometry.init(128, parallel, wide);
            try std.testing.expectEqual(@as(usize, 256), geometry.job_size);
            try std.testing.expectEqual(@as(usize, 4), geometry.slot_count);
            const one = try types.Geometry.init(128, parallel, 1);
            try std.testing.expectEqual(@as(usize, 1), one.slot_count);
            try std.testing.expectEqual(@as(usize, 0), one.worker_count);
        }
    };
}
