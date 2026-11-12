//! Linux opening-thread userspace PMU groups. Control syscalls occur at batch
//! boundaries only. Raw counters are never scaled or replaced on failure.
const std = @import("std");
const builtin = @import("builtin");
const linux = std.os.linux;

pub const Kind = enum { branches, branch_misses };
pub const event_count = 3;
pub const read_word_count = 9;
pub const read_byte_count = read_word_count * @sizeOf(u64);
const native_endian = builtin.target.cpu.arch.endian();
const read_format: u64 = (1 << 0) | (1 << 1) | (1 << 2) | (1 << 3);
const group_flag: usize = 1;
const close_on_exec: usize = 1 << 3;

pub const Counts = struct {
    cycles: u64,
    instructions: u64,
    third_event: u64,
    time_enabled: u64,
    time_running: u64,
    /// Exact kernel payload order: nr, enabled, running, then three value/ID pairs.
    raw_words: [read_word_count]u64,
    /// Semantic order, independent of the kernel read's pair ordering.
    event_ids: [event_count]u64,
};

pub const Error = error{
    LinuxPerfRequired,
    PerfPermissionDenied,
    PerfUnavailable,
    PerfSchedulingUnavailable,
    PerfDescriptorLimit,
    PerfConfigurationRejected,
    PerfOpenFailed,
    PerfIdReadFailed,
    PerfControlFailed,
    PerfReadFailed,
    PerfGroupClosed,
    PerfGroupAlreadyRunning,
    PerfUnreadBatch,
    PerfBatchNotStopped,
    PerfNoStoppedBatch,
    PerfReadTruncated,
    PerfReadSizeMismatch,
    PerfEventCountMismatch,
    PerfInvalidExpectedIds,
    PerfInvalidReadId,
    PerfDuplicateReadId,
    PerfUnknownReadId,
    PerfZeroCoreCounts,
    PerfZeroTime,
    PerfInvalidRunningTime,
    PerfGroupNotFullyRunning,
};

pub fn metadata(kind: Kind) struct {
    kind: Kind,
    events: [event_count][]const u8,
    hardware_configs: [event_count]u64,
    read_format: u64,
    pid_argument: i32,
    cpu_argument: i32,
    disabled_at_open: bool,
    inherit: bool,
    exclude_kernel: bool,
    exclude_hv: bool,
    values_scaled: bool,
    strict_full_running_time: bool,
    scope: []const u8,
    time_scope: []const u8,
} {
    return .{
        .kind = kind,
        .events = .{ "cycles", "instructions", if (kind == .branches) "branches" else "branch-misses" },
        .hardware_configs = configs(kind),
        .read_format = read_format,
        .pid_argument = 0,
        .cpu_argument = -1,
        .disabled_at_open = true,
        .inherit = false,
        .exclude_kernel = true,
        .exclude_hv = true,
        .values_scaled = false,
        .strict_full_running_time = true,
        .scope = "Opening-thread userspace interval between kernel group-enable/disable; includes wrapper return/entry overhead. Caller keeps clocks and validation outside and must use the opening thread.",
        .time_scope = "Exact kernel cumulative enabled/running fields over this FD lifetime; RESET clears counts but not these time fields. No silent scaling or per-batch time fabrication.",
    };
}

fn configs(kind: Kind) [event_count]u64 {
    // linux/perf_event.h: PERF_COUNT_HW_CPU_CYCLES, INSTRUCTIONS, BRANCH_*
    return .{ 0, 1, if (kind == .branches) 4 else 5 };
}

fn validExpectedIds(ids: [event_count]u64) bool {
    return ids[0] != 0 and ids[1] != 0 and ids[2] != 0 and
        ids[0] != ids[1] and ids[0] != ids[2] and ids[1] != ids[2];
}

/// Pure GROUP/TIME_ENABLED/TIME_RUNNING/ID parsing. IDs, rather than record
/// position, bind each value to its semantic event. A valid third event may be 0.
pub fn parseWords(expected_ids: [event_count]u64, words: [read_word_count]u64) Error!Counts {
    if (!validExpectedIds(expected_ids)) return error.PerfInvalidExpectedIds;
    if (words[0] != event_count) return error.PerfEventCountMismatch;
    var values: [event_count]u64 = undefined;
    var seen: [event_count]bool = @splat(false);
    for (0..event_count) |index| {
        const id = words[4 + 2 * index];
        if (id == 0) return error.PerfInvalidReadId;
        const target = std.mem.indexOfScalar(u64, &expected_ids, id) orelse return error.PerfUnknownReadId;
        if (seen[target]) return error.PerfDuplicateReadId;
        seen[target] = true;
        values[target] = words[3 + 2 * index];
    }
    if (values[0] == 0 or values[1] == 0) return error.PerfZeroCoreCounts;
    if (words[1] == 0 or words[2] == 0) return error.PerfZeroTime;
    if (words[2] > words[1]) return error.PerfInvalidRunningTime;
    if (words[2] != words[1]) return error.PerfGroupNotFullyRunning;
    return .{ .cycles = values[0], .instructions = values[1], .third_event = values[2], .time_enabled = words[1], .time_running = words[2], .raw_words = words, .event_ids = expected_ids };
}

fn wordsFromBytes(bytes: *const [read_byte_count]u8) [read_word_count]u64 {
    var words: [read_word_count]u64 = undefined;
    for (&words, 0..) |*word, index|
        word.* = std.mem.readInt(u64, bytes[index * 8 ..][0..8], native_endian);
    return words;
}

pub fn parseRead(expected_ids: [event_count]u64, bytes: []const u8) Error!Counts {
    if (bytes.len < read_byte_count) return error.PerfReadTruncated;
    if (bytes.len != read_byte_count) return error.PerfReadSizeMismatch;
    return parseWords(expected_ids, wordsFromBytes(bytes[0..read_byte_count]));
}

pub const ReadDiagnostic = struct {
    /// Only raw_bytes[0..byte_count] came from the kernel; remaining bytes are padding.
    byte_count: usize,
    raw_bytes: [read_byte_count]u8,
    raw_words: ?[read_word_count]u64,
    expected_event_ids: [event_count]u64,
};

/// Owns three FDs. Do not copy an opened Group or move use to another thread.
pub const Group = struct {
    kind: Kind,
    fds: [event_count]linux.fd_t = @splat(-1),
    event_ids: [event_count]u64 = @splat(0),
    running: bool = false,
    ready_for_read: bool = false,
    last_read: ?ReadDiagnostic = null,

    pub fn open(kind: Kind) Error!Group {
        if (comptime builtin.os.tag != .linux) return error.LinuxPerfRequired;
        var group: Group = .{ .kind = kind };
        errdefer group.deinit();
        for (configs(kind), 0..) |config, index| {
            var attribute: linux.perf_event_attr = .{
                .type = .HARDWARE,
                .size = 64, // PERF_ATTR_SIZE_VER0: all required fields, no extension ABI.
                .config = config,
                .read_format = read_format,
                .flags = .{ .disabled = true, .exclude_kernel = true, .exclude_hv = true },
            };
            const result = linux.perf_event_open(&attribute, 0, -1, if (index == 0) -1 else group.fds[0], close_on_exec);
            switch (linux.errno(result)) {
                .SUCCESS => group.fds[index] = @intCast(result),
                .ACCES, .PERM => return error.PerfPermissionDenied,
                .NOENT, .NODEV, .NOSYS, .OPNOTSUPP => return error.PerfUnavailable,
                .BUSY, .NOSPC => return error.PerfSchedulingUnavailable,
                .MFILE, .NFILE => return error.PerfDescriptorLimit,
                .INVAL => return error.PerfConfigurationRejected,
                else => return error.PerfOpenFailed,
            }
            var id: u64 = 0;
            const request = linux.IOCTL.IOR('$', 7, *u64);
            try ioctlRetry(group.fds[index], request, @intFromPtr(&id), error.PerfIdReadFailed);
            group.event_ids[index] = id;
        }
        if (!validExpectedIds(group.event_ids)) return error.PerfInvalidExpectedIds;
        return group;
    }

    pub fn begin(self: *Group) Error!void {
        // Clear even on a failed begin attempt: a caller must not attach a
        // previous batch's raw read to this new pair's failure report.
        self.last_read = null;
        if (self.fds[0] < 0) return error.PerfGroupClosed;
        if (self.running) return error.PerfGroupAlreadyRunning;
        if (self.ready_for_read) return error.PerfUnreadBatch;
        errdefer self.deinit();
        try ioctlRetry(self.fds[0], linux.IOCTL.IO('$', 3), group_flag, error.PerfControlFailed);
        try ioctlRetry(self.fds[0], linux.IOCTL.IO('$', 0), group_flag, error.PerfControlFailed);
        self.running = true;
    }

    pub fn stop(self: *Group) Error!void {
        if (self.fds[0] < 0) return error.PerfGroupClosed;
        if (!self.running) return;
        // On a disable failure, closing every FD prevents any subsequent
        // reference-side work from accidentally remaining inside the group.
        errdefer self.deinit();
        try ioctlRetry(self.fds[0], linux.IOCTL.IO('$', 1), group_flag, error.PerfControlFailed);
        self.running = false;
        self.ready_for_read = true;
    }

    /// Abort a failed decode batch. The unread failed batch is deliberately
    /// discarded; disable failure closes the group instead of hiding a live FD.
    pub fn stopQuietly(self: *Group) void {
        self.stop() catch self.deinit();
        self.ready_for_read = false;
    }

    pub fn read(self: *Group) Error!Counts {
        if (self.fds[0] < 0) return error.PerfGroupClosed;
        if (self.running) return error.PerfBatchNotStopped;
        if (!self.ready_for_read) return error.PerfNoStoppedBatch;
        errdefer self.deinit();
        var bytes: [read_byte_count]u8 = undefined;
        const byte_count = while (true) {
            @memset(&bytes, 0);
            const result = linux.read(self.fds[0], &bytes, bytes.len);
            switch (linux.errno(result)) {
                .SUCCESS => break result,
                .INTR => continue,
                else => return error.PerfReadFailed,
            }
        };
        self.last_read = .{ .byte_count = byte_count, .raw_bytes = bytes, .raw_words = if (byte_count == read_byte_count) wordsFromBytes(&bytes) else null, .expected_event_ids = self.event_ids };
        if (byte_count > bytes.len) return error.PerfReadSizeMismatch;
        const result = try parseRead(self.event_ids, bytes[0..byte_count]);
        self.ready_for_read = false;
        return result;
    }

    pub fn diagnostic(self: *const Group) ?ReadDiagnostic {
        return self.last_read;
    }

    /// Close members before the leader. Preserve last_read for error reporting.
    pub fn deinit(self: *Group) void {
        if (comptime builtin.os.tag == .linux) {
            var index: usize = event_count;
            while (index != 0) {
                index -= 1;
                const fd = self.fds[index];
                self.fds[index] = -1;
                if (fd >= 0) _ = linux.close(fd); // Linux close must not be retried.
            }
        }
        self.running = false;
        self.ready_for_read = false;
    }
};

fn ioctlRetry(fd: linux.fd_t, request: u32, argument: usize, failure: Error) Error!void {
    while (true) {
        switch (linux.errno(linux.ioctl(fd, request, argument))) {
            .SUCCESS => return,
            .INTR => continue,
            else => return failure,
        }
    }
}
