//! Explicit one-shot Job geometry and observations for one Zstd frame.
const std = @import("std");
const builtin = @import("builtin");
const core = @import("../../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || std.Thread.SpawnError || error{WorkingMemoryLimitExceeded};
pub const worker_stack_bytes: usize = 2 * 1024 * 1024;
pub const target_supports_parallel = !builtin.single_threaded and
    (builtin.os.tag == .linux or builtin.os.tag == .windows or std.Thread.use_pthreads);

pub const Profile = struct {
    available: bool = false,
    serial_fallback: bool = false,
    configured_workers: usize = 0,
    effective_workers: usize = 0,
    workers_started: usize = 0,
    workers_live: usize = 0,
    /// Peak concurrently encoding OS workers; synchronous fallback is zero.
    peak_active_workers: usize = 0,
    effective_job_size: usize = 0,
    job_count: usize = 0,
    encoded_jobs: usize = 0,
    published_jobs: usize = 0,
    encoded_blocks: usize = 0,
    published_blocks: usize = 0,
    peak_inflight_jobs: usize = 0,
    peak_inflight_bytes: usize = 0,
    /// Live Job output capacity; zero after the one-shot queue is destroyed.
    retained_job_output_capacity: usize = 0,
    peak_job_output_capacity: usize = 0,
    peak_requested_bytes: usize = 0,
    live_requested_bytes: usize = 0,

    pub fn reset(self: *Profile) void {
        self.* = .{};
    }
};

pub const Options = struct {
    io: std.Io,
    worker_count: usize = 2,
    job_size: usize = 1024 * 1024,
    max_inflight_jobs: usize = 4,
    max_inflight_bytes: usize = 4 * 1024 * 1024,
    max_working_memory: usize = 256 * 1024 * 1024,
    /// Cut Jobs at content-defined synchronization points so a small input
    /// edit only changes the surrounding Job. Requires `job_size` of at least
    /// `rsync_min_job_size`; the average interval follows `job_size`.
    rsyncable: bool = false,
    profile: ?*Profile = null,

    pub fn validate(self: Options) Error!void {
        if (self.worker_count == 0 or self.worker_count > 64 or self.job_size == 0 or
            self.max_inflight_jobs == 0 or self.max_inflight_bytes == 0)
            return error.InvalidBlockPlan;
        if (self.rsyncable) _ = try rsyncBits(self.job_size);
    }
};

pub const rsync_min_job_size: usize = 512 * 1024;
/// Upstream refuses synchronization points that would create Jobs smaller
/// than one maximum-size Zstd block.
pub const rsync_min_block_size: usize = 128 * 1024;
pub const rsync_window: usize = 32;
const rsync_prime: u64 = 0xCF1BBCDCB7A56463;
const rsync_char_offset: u64 = 10;

fn rsyncBits(job_size: usize) Error!u6 {
    if (job_size < rsync_min_job_size) return error.InvalidBlockPlan;
    const log = std.math.log2_int(usize, job_size >> 10);
    if (log >= 54) return error.InvalidBlockPlan;
    return @intCast(log + 10);
}

/// Upstream-compatible rolling hash and hit mask for one `job_size`. The
/// average interval between synchronization points is `job_size` bytes.
pub const Rsync = struct {
    hit_mask: u64,
    prime_power: u64,

    pub fn init(job_size: usize) Error!Rsync {
        const bits = try rsyncBits(job_size);
        return .{
            .hit_mask = (@as(u64, 1) << bits) - 1,
            .prime_power = primePower(rsync_prime, rsync_window - 1),
        };
    }

    /// End offset of the Job starting at `start`, capped at `job_size` bytes
    /// and at the input end. A synchronization point is only considered after
    /// `rsync_min_block_size` bytes, so a hit yields a Job at least that long.
    pub fn jobEnd(
        self: Rsync,
        input: []const u8,
        start: usize,
        job_size: usize,
    ) usize {
        const remaining = input.len - start;
        const nominal_end = start + @min(job_size, remaining);
        if (remaining <= rsync_min_block_size + rsync_window)
            return nominal_end;
        var position = start + rsync_min_block_size;
        var hash = rollingHash(input[position - rsync_window .. position]);
        while (true) {
            if (hash & self.hit_mask == self.hit_mask) return position;
            if (position == nominal_end) return nominal_end;
            hash = rollingRotate(
                hash,
                input[position - rsync_window],
                input[position],
                self.prime_power,
            );
            position += 1;
        }
    }

    pub const ChunkScan = struct {
        /// Input bytes to accept before the current Job ends.
        take: usize,
        /// True when a synchronization point ends the Job at `take`.
        hit: bool,
    };

    /// Scan one streaming chunk that follows `before`, the last up-to
    /// `rsync_window` bytes already accepted into the current Job.
    /// `accepted_len` is that Job's current plain length. The first candidate
    /// is at or after `rsync_min_block_size`; the whole chunk is accepted when
    /// no point is found. A hit at `take == 0` means the current Job is
    /// already at a synchronization point.
    pub fn scanChunk(
        self: Rsync,
        before: []const u8,
        input: []const u8,
        accepted_len: usize,
    ) ChunkScan {
        var position: usize = if (accepted_len >= rsync_min_block_size)
            0
        else
            rsync_min_block_size - accepted_len;
        if (position >= input.len) return .{ .take = input.len, .hit = false };
        var window: [rsync_window]u8 = undefined;
        if (position >= rsync_window) {
            @memcpy(window[0..], input[position - rsync_window .. position]);
        } else {
            const from_before = rsync_window - position;
            if (before.len < from_before)
                return .{ .take = input.len, .hit = false };
            @memcpy(
                window[0..from_before],
                before[before.len - from_before ..],
            );
            @memcpy(window[from_before..], input[0..position]);
        }
        var hash = rollingHash(&window);
        var head: usize = 0;
        while (true) {
            if (hash & self.hit_mask == self.hit_mask)
                return .{ .take = position, .hit = true };
            if (position == input.len)
                return .{ .take = input.len, .hit = false };
            const remove = window[head];
            window[head] = input[position];
            head = (head + 1) & (rsync_window - 1);
            hash = rollingRotate(
                hash,
                remove,
                input[position],
                self.prime_power,
            );
            position += 1;
        }
    }
};

fn primePower(base: u64, exponent: usize) u64 {
    var power: u64 = 1;
    var factor = base;
    var remaining = exponent;
    while (remaining != 0) : (remaining >>= 1) {
        if (remaining & 1 != 0) power *%= factor;
        factor *%= factor;
    }
    return power;
}

fn rollingHash(bytes: []const u8) u64 {
    var hash: u64 = 0;
    for (bytes) |byte| {
        hash = hash *% rsync_prime +% (@as(u64, byte) + rsync_char_offset);
    }
    return hash;
}

fn rollingRotate(hash: u64, remove: u8, add: u8, prime_power: u64) u64 {
    var value = hash -% (@as(u64, remove) + rsync_char_offset) *% prime_power;
    value = value *% rsync_prime +% (@as(u64, add) + rsync_char_offset);
    return value;
}

pub const Geometry = struct {
    block_size: usize,
    job_size: usize,
    job_count: usize,
    slot_count: usize,
    worker_count: usize,

    pub fn init(input_len: usize, block_size: usize, options: Options) Error!Geometry {
        try options.validate();
        if (block_size == 0) return error.InvalidBlockPlan;
        const remainder = options.job_size % block_size;
        const job_size = if (remainder == 0) options.job_size else std.math.add(usize, options.job_size, block_size - remainder) catch return error.IntegerOverflow;
        if (@min(input_len, job_size) > options.max_inflight_bytes)
            return error.WorkingMemoryLimitExceeded;
        const job_count = if (input_len == 0)
            1
        else if (options.rsyncable)
            1 + (input_len - 1) / rsync_min_block_size
        else
            1 + (input_len - 1) / job_size;
        const byte_slots = 1 + (options.max_inflight_bytes - 1) / job_size;
        const slots = @min(job_count, @min(options.max_inflight_jobs, byte_slots));
        const available_workers = @min(options.worker_count, slots);
        return .{
            .block_size = block_size,
            .job_size = job_size,
            .job_count = job_count,
            .slot_count = slots,
            .worker_count = if (target_supports_parallel and available_workers > 1) available_workers else 0,
        };
    }

    pub fn blockCount(self: Geometry, start: usize, end: usize) usize {
        return if (start == end) 1 else 1 + (end - start - 1) / self.block_size;
    }
};

test "Zstd parallel geometry admits a full Job and one-byte tail with exact credit" {
    const geometry = try Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1025,
    });
    try std.testing.expectEqual(@as(usize, 1024), geometry.job_size);
    try std.testing.expectEqual(@as(usize, 2), geometry.job_count);
    try std.testing.expectEqual(@as(usize, 2), geometry.slot_count);
    try std.testing.expectEqual(if (target_supports_parallel) @as(usize, 2) else 0, geometry.worker_count);
}

test "Zstd parallel geometry one full Job of credit keeps one slot" {
    const geometry = try Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1024,
    });
    try std.testing.expectEqual(@as(usize, 2), geometry.job_count);
    try std.testing.expectEqual(@as(usize, 1), geometry.slot_count);
    try std.testing.expectEqual(@as(usize, 0), geometry.worker_count);
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Geometry.init(1025, 128, .{
        .io = .failing,
        .job_size = 1024,
        .max_inflight_bytes = 1023,
    }));
}

test "Zstd parallel geometry checks rounding overflow and exact maximum ceiling" {
    const maximum: usize = std.math.maxInt(usize);
    try std.testing.expectError(error.IntegerOverflow, Geometry.init(1, 128, .{
        .io = .failing,
        .job_size = maximum,
        .max_inflight_bytes = maximum,
    }));
    const geometry = try Geometry.init(maximum, 1, .{
        .io = .failing,
        .job_size = 1,
        .max_inflight_bytes = maximum,
    });
    try std.testing.expectEqual(maximum, geometry.job_count);
    try std.testing.expectEqual(@as(usize, 4), geometry.slot_count);
}

test "Zstd rsyncable options require the upstream minimum Job size" {
    try std.testing.expectError(error.InvalidBlockPlan, Rsync.init(rsync_min_job_size - 1));
    const rsync = try Rsync.init(rsync_min_job_size);
    try std.testing.expectEqual(@as(u64, (1 << 19) - 1), rsync.hit_mask);
    try std.testing.expectError(error.InvalidBlockPlan, (Options{
        .io = .failing,
        .job_size = rsync_min_job_size - 1,
        .rsyncable = true,
    }).validate());
    try (Options{
        .io = .failing,
        .job_size = rsync_min_job_size,
        .rsyncable = true,
    }).validate();
    const geometry = try Geometry.init(1024 * 1024, 128 * 1024, .{
        .io = .failing,
        .job_size = rsync_min_job_size,
        .max_inflight_bytes = 1024 * 1024,
        .rsyncable = true,
    });
    try std.testing.expectEqual(@as(usize, 8), geometry.job_count);
    try std.testing.expectEqual(@as(usize, 2), geometry.slot_count);
}

fn collectRsyncBoundaries(
    allocator: std.mem.Allocator,
    rsync: Rsync,
    input: []const u8,
    job_size: usize,
) ![]usize {
    var boundaries: std.ArrayList(usize) = .empty;
    errdefer boundaries.deinit(allocator);
    var start: usize = 0;
    while (true) {
        const end = rsync.jobEnd(input, start, job_size);
        if (end <= start or end > input.len) return error.TestUnexpectedResult;
        try boundaries.append(allocator, end);
        if (end == input.len) break;
        start = end;
    }
    return boundaries.toOwnedSlice(allocator);
}

test "Zstd rsyncable boundaries are deterministic and minimum-block bounded" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 4 * 1024 * 1024);
    defer allocator.free(input);
    var state: u32 = 0x1234_5678;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 16);
    }
    inline for (.{ rsync_min_job_size, 1024 * 1024, 2 * 1024 * 1024 }) |job_size| {
        const rsync = try Rsync.init(job_size);
        const first = try collectRsyncBoundaries(allocator, rsync, input, job_size);
        defer allocator.free(first);
        const second = try collectRsyncBoundaries(allocator, rsync, input, job_size);
        defer allocator.free(second);
        try std.testing.expectEqualSlices(usize, first, second);
        var start: usize = 0;
        for (first, 0..) |end, index| {
            try std.testing.expect(end - start <= job_size);
            if (index + 1 < first.len)
                try std.testing.expect(end - start >= rsync_min_block_size);
            start = end;
        }
        try std.testing.expectEqual(input.len, first[first.len - 1]);
    }
}

test "Zstd rsyncable chunk scanner matches whole-input boundaries" {
    const allocator = std.testing.allocator;
    const input = try allocator.alloc(u8, 2 * 1024 * 1024);
    defer allocator.free(input);
    var state: u32 = 0x0bad_f00d;
    for (input) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 15);
    }
    const job_size = 512 * 1024;
    const rsync = try Rsync.init(job_size);
    const whole = try collectRsyncBoundaries(allocator, rsync, input, job_size);
    defer allocator.free(whole);
    inline for (.{ 1, 7, 4096, 65536 }) |chunk_size| {
        var boundaries: std.ArrayList(usize) = .empty;
        defer boundaries.deinit(allocator);
        var before: [rsync_window]u8 = undefined;
        var before_len: usize = 0;
        var offset: usize = 0;
        var accepted: usize = 0;
        while (offset < input.len) {
            if (accepted == job_size) {
                try boundaries.append(allocator, offset);
                accepted = 0;
                continue;
            }
            const room = job_size - accepted;
            const chunk = input[offset..][0..@min(@min(chunk_size, input.len - offset), room)];
            const scan = rsync.scanChunk(before[0..before_len], chunk, accepted);
            if (scan.hit and scan.take == 0) {
                try boundaries.append(allocator, offset);
                accepted = 0;
                continue;
            }
            const take = if (scan.hit) scan.take else chunk.len;
            offset += take;
            accepted += take;
            before_len = @min(rsync_window, offset);
            @memcpy(before[0..before_len], input[offset - before_len .. offset]);
            if (scan.hit) {
                try boundaries.append(allocator, offset);
                accepted = 0;
            }
        }
        if (accepted != 0) try boundaries.append(allocator, input.len);
        try std.testing.expectEqualSlices(usize, whole, boundaries.items);
    }
}

test "Zstd rsyncable edit at a boundary only shifts later boundaries" {
    const allocator = std.testing.allocator;
    const original = try allocator.alloc(u8, 3 * 1024 * 1024);
    defer allocator.free(original);
    var state: u32 = 0xdead_beef;
    for (original) |*byte| {
        state = state *% 1_664_525 +% 1_013_904_223;
        byte.* = @truncate(state >> 13);
    }
    const job_size = 1024 * 1024;
    const rsync = try Rsync.init(job_size);
    const before = try collectRsyncBoundaries(allocator, rsync, original, job_size);
    defer allocator.free(before);
    try std.testing.expect(before.len >= 3);

    const insertion = try allocator.alloc(u8, 1000);
    defer allocator.free(insertion);
    for (insertion, 0..) |*byte, index| byte.* = @truncate(index * 37 + 11);
    const edited = try allocator.alloc(u8, original.len + insertion.len);
    defer allocator.free(edited);
    const cut = before[0];
    @memcpy(edited[0..cut], original[0..cut]);
    @memcpy(edited[cut..][0..insertion.len], insertion);
    @memcpy(edited[cut + insertion.len ..], original[cut..]);

    const after = try collectRsyncBoundaries(allocator, rsync, edited, job_size);
    defer allocator.free(after);
    try std.testing.expectEqual(cut, after[0]);
    try std.testing.expectEqual(before.len, after.len);
    for (before[1..], after[1..]) |old_end, new_end| {
        try std.testing.expectEqual(old_end + insertion.len, new_end);
    }
}
