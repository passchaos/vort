//! Independent frame framing, a second decoder, and allocator observations.
const std = @import("std");
const types = @import("../types.zig");
pub const a = std.testing.allocator;
pub const full_dictionary = @import("../../encode/hq_test_helpers.zig").fullDictionary;

pub fn native(comptime Z: type) Z.NativeFrameOptions {
    return .{ .block_size_max = 128, .window_log = 10, .content_checksum = true };
}

pub fn parallel(comptime Z: type, profile: *Z.ParallelProfile, workers: usize) Z.ParallelOptions {
    return .{ .io = std.testing.io, .worker_count = workers, .job_size = 129, .max_inflight_jobs = 2, .max_inflight_bytes = 512, .max_working_memory = 64 * 1024 * 1024, .profile = profile };
}

pub fn noise(bytes: []u8, seed: u32) void {
    var state = seed;
    for (bytes) |*byte| {
        state = state *% 1664525 +% 1013904223;
        byte.* = @truncate(state >> 24);
    }
}

pub fn structured() [1025]u8 {
    var bytes: [1025]u8 = undefined;
    const text = "{\"service\":\"vort\",\"items\":[1,4,8],\"status\":\"repeated\"}\n";
    for (&bytes, 0..) |*byte, i| byte.* = if (i % 97 == 0) @truncate(i / 97) else text[i % text.len];
    return bytes;
}

fn integer(bytes: []const u8, cursor: *usize, count: usize) !u64 {
    try std.testing.expect(count <= 8 and cursor.* <= bytes.len and count <= bytes.len - cursor.*);
    var value: u64 = 0;
    for (bytes[cursor.*..][0..count], 0..) |byte, i| value |= @as(u64, byte) << @intCast(i * 8);
    cursor.* += count;
    return value;
}

pub const Summary = struct {
    blocks: usize = 0,
    raw: usize = 0,
    rle: usize = 0,
    compressed: usize = 0,
    literal_only_compressed: usize = 0,
    kinds: [64]u2 = @splat(0),
};

fn literalOnly(block: []const u8) !bool {
    try std.testing.expect(block.len > 0);
    const kind = block[0] & 3;
    const format = (block[0] >> 2) & 3;
    const header_size: usize = if (kind < 2) (if (format == 0 or format == 2) 1 else if (format == 1) 2 else 3) else switch (format) {
        0, 1 => 3,
        2 => 4,
        else => 5,
    };
    var cursor: usize = 0;
    const header = try integer(block, &cursor, header_size);
    const shift: u6 = switch (format) {
        0, 1 => 14,
        2 => 18,
        else => 22,
    };
    const mask: u64 = switch (format) {
        0, 1 => 0x3ff,
        2 => 0x3fff,
        else => 0x3ffff,
    };
    const packed_size: usize = if (kind < 2) (if (kind == 1) 1 else @intCast(header >> @as(u6, if (header_size == 1) 3 else 4))) else @intCast((header >> shift) & mask);
    try std.testing.expect(header_size + packed_size < block.len);
    if (block[header_size + packed_size] != 0) return false;
    try std.testing.expectEqual(block.len, header_size + packed_size + 1);
    return true;
}

/// RFC 8878 frame envelope, independent of vort's frame/block inspectors.
/// Exhausting the frame exactly after one Last_Block and one optional checksum
/// rejects concatenated job frames, extra last bits and per-job trailers.
pub fn envelope(comptime Z: type, frame: []const u8, input: []const u8, options: Z.NativeFrameOptions, dictionary_id: u32) !Summary {
    var cursor: usize = 0;
    if (options.format == .standard) {
        try std.testing.expectEqual(@as(u64, 0xfd2fb528), try integer(frame, &cursor, 4));
    }
    const descriptor: u8 = @intCast(try integer(frame, &cursor, 1));
    try std.testing.expect(descriptor & 0x18 == 0);
    try std.testing.expectEqual(options.content_checksum, descriptor & 4 != 0);
    const single = descriptor & 0x20 != 0;
    if (!single) _ = try integer(frame, &cursor, 1);
    const dict_size: usize = switch (descriptor & 3) {
        0 => 0,
        1 => 1,
        2 => 2,
        else => 4,
    };
    try std.testing.expectEqual(@as(u64, dictionary_id), try integer(frame, &cursor, dict_size));
    const size_flag = descriptor >> 6;
    const size_bytes: usize = switch (size_flag) {
        0 => if (single) 1 else 0,
        1 => 2,
        2 => 4,
        else => 8,
    };
    const stored_size = try integer(frame, &cursor, size_bytes);
    if (options.include_content_size) {
        try std.testing.expect(size_bytes != 0);
        try std.testing.expectEqual(@as(u64, input.len), stored_size + @as(u64, if (size_flag == 1) 256 else 0));
    } else try std.testing.expectEqual(@as(usize, 0), size_bytes);
    var summary: Summary = .{};
    while (true) {
        const header = try integer(frame, &cursor, 3);
        const kind: u2 = @intCast((header >> 1) & 3);
        const length: usize = @intCast(header >> 3);
        try std.testing.expect(kind != 3 and summary.blocks < summary.kinds.len);
        summary.kinds[summary.blocks] = kind;
        summary.blocks += 1;
        switch (kind) {
            0 => summary.raw += 1,
            1 => summary.rle += 1,
            2 => summary.compressed += 1,
            else => unreachable,
        }
        const packed_size = if (kind == 1) @as(usize, 1) else length;
        try std.testing.expect(cursor <= frame.len and packed_size <= frame.len - cursor);
        if (kind == 2 and try literalOnly(frame[cursor..][0..packed_size])) summary.literal_only_compressed += 1;
        cursor += packed_size;
        if (header & 1 != 0) break;
    }
    if (options.content_checksum) {
        const actual = try integer(frame, &cursor, 4);
        try std.testing.expectEqual(@as(u64, @as(u32, @truncate(std.hash.XxHash64.hash(0, input)))), actual);
    }
    try std.testing.expectEqual(frame.len, cursor);
    return summary;
}

pub fn stdDecode(frame: []const u8, magicless: bool) ![]u8 {
    var normalized: std.ArrayList(u8) = .empty;
    defer normalized.deinit(a);
    if (magicless) try normalized.appendSlice(a, &.{ 0x28, 0xb5, 0x2f, 0xfd });
    try normalized.appendSlice(a, frame);
    var source: std.Io.Reader = .fixed(normalized.items);
    var output: std.Io.Writer.Allocating = .init(a);
    defer output.deinit();
    var decoder: std.compress.zstd.Decompress = .init(&source, &.{}, .{ .window_len = 128 * 1024 });
    _ = try decoder.reader.streamRemaining(&output.writer);
    return output.toOwnedSlice();
}

pub fn verify(comptime Z: type, frame: []const u8, input: []const u8, options: Z.NativeFrameOptions, dictionary: ?Z.NativeDictionary) !Summary {
    const summary = try envelope(Z, frame, input, options, if (dictionary) |d| d.id else 0);
    const decoded = try Z.decodeFrameAllocWithOptions(a, frame, .{ .format = options.format, .dictionary = dictionary });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    if (dictionary == null) {
        const independent = try stdDecode(frame, options.format == .magicless);
        defer a.free(independent);
        try std.testing.expectEqualSlices(u8, input, independent);
    }
    return summary;
}

pub fn complete(comptime Z: type, profile: Z.ParallelProfile, input_len: usize, options: Z.NativeFrameOptions, limits: Z.ParallelOptions, wire_blocks: usize) !void {
    const job_size = ((limits.job_size - 1) / options.block_size_max + 1) * options.block_size_max;
    const jobs = if (input_len == 0) @as(usize, 1) else 1 + (input_len - 1) / job_size;
    const slots = @min(jobs, @min(limits.max_inflight_jobs, @max(@as(usize, 1), limits.max_inflight_bytes / job_size)));
    const workers = if (types.target_supports_parallel and @min(limits.worker_count, slots) > 1) @min(limits.worker_count, slots) else 0;
    try std.testing.expect(profile.available);
    try std.testing.expectEqual(job_size, profile.effective_job_size);
    try std.testing.expectEqual(jobs, profile.job_count);
    try std.testing.expectEqual(jobs, profile.encoded_jobs);
    try std.testing.expectEqual(jobs, profile.published_jobs);
    try std.testing.expectEqual(wire_blocks, profile.encoded_blocks);
    try std.testing.expectEqual(wire_blocks, profile.published_blocks);
    try std.testing.expectEqual(workers, profile.workers_started);
    try std.testing.expectEqual(@as(usize, 0), profile.workers_live);
    try std.testing.expectEqual(workers == 0, profile.serial_fallback);
    try std.testing.expect(profile.peak_inflight_jobs <= limits.max_inflight_jobs and profile.peak_inflight_bytes <= limits.max_inflight_bytes);
    try std.testing.expect(profile.peak_requested_bytes > 0 and profile.peak_requested_bytes <= @min(limits.max_working_memory, options.max_total_working_memory orelse std.math.maxInt(usize)));
    try std.testing.expectEqual(@as(usize, 0), profile.live_requested_bytes);
    if (workers != 0) try std.testing.expect(profile.peak_active_workers > 0 and profile.peak_active_workers <= workers);
}

pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

/// Serial backing with a reentry detector protects even the faulty-test path
/// from racing its own bookkeeping. The production budget supplies the lock.
pub const Heap = struct {
    backing: std.mem.Allocator,
    active: std.atomic.Value(bool) = .init(false),
    reentries: std.atomic.Value(usize) = .init(0),
    calls: usize = 0,
    live: usize = 0,
    peak: usize = 0,

    pub fn init(backing: std.mem.Allocator) Heap {
        return .{ .backing = backing };
    }
    pub fn allocator(self: *Heap) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn enter(self: *Heap) bool {
        if (self.active.swap(true, .acquire)) {
            _ = self.reentries.fetchAdd(1, .monotonic);
            return false;
        }
        self.calls += 1;
        for (0..64) |_| std.atomic.spinLoopHint();
        return true;
    }
    fn leave(self: *Heap) void {
        self.active.store(false, .release);
    }
    fn changed(self: *Heap, old: usize, new: usize) void {
        self.live = self.live - old + new;
        self.peak = @max(self.peak, self.live);
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(raw));
        if (!self.enter()) return null;
        defer self.leave();
        const result = self.backing.rawAlloc(len, alignment, address) orelse return null;
        self.changed(0, len);
        return result;
    }
    fn resize(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *Heap = @ptrCast(@alignCast(raw));
        if (!self.enter()) return false;
        defer self.leave();
        if (!self.backing.rawResize(bytes, alignment, len, address)) return false;
        self.changed(bytes.len, len);
        return true;
    }
    fn remap(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *Heap = @ptrCast(@alignCast(raw));
        if (!self.enter()) return null;
        defer self.leave();
        const result = self.backing.rawRemap(bytes, alignment, len, address) orelse return null;
        self.changed(bytes.len, len);
        return result;
    }
    fn free(raw: *anyopaque, bytes: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *Heap = @ptrCast(@alignCast(raw));
        if (!self.enter()) return;
        defer self.leave();
        self.backing.rawFree(bytes, alignment, address);
        self.changed(bytes.len, 0);
    }
};
