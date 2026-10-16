//! Bounded mixed raw/compressed CPIO sequence reader for initramfs streams.

const std = @import("std");
const auto_reader = @import("incremental_auto_reader.zig");
const cpio_reader = @import("incremental_reader.zig");

pub const Error = auto_reader.Error || std.mem.Allocator.Error || error{
    InvalidCpioMixedReaderState,
    CpioMixedReaderPoisoned,
};

pub const Options = struct {
    auto: auto_reader.Options = .{},
    max_members: usize = std.math.maxInt(usize),
    max_padding_size: u64 = std.math.maxInt(u64),
    max_total_input_size: u64 = std.math.maxInt(u64),
    max_total_output_size: u64 = std.math.maxInt(u64),
    decoder_input_chunk_size: usize = 32 * 1024,
    max_replay_size: usize = 64 * 1024,
};

pub const Phase = enum { padding, member, done, poisoned };

pub const Status = enum {
    need_input,
    need_output,
    entry_header,
    entry_done,
    archive_done,
    done,
};

pub const StepResult = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    status: Status,
};

pub const ArchiveInfo = struct {
    index: usize,
    format: auto_reader.Format,
    input_offset: u64,
    input_size: u64,
    entry_count: usize,
    output_size: usize,
    recovered_suffix_size: usize,
};

pub const Reader = struct {
    allocator: std.mem.Allocator,
    options: Options,
    auto: auto_reader.Reader,
    replay: std.ArrayList(u8) = .empty,
    replay_offset: usize = 0,
    phase: Phase = .padding,
    member_count: usize = 0,
    member_start: u64 = 0,
    last_archive: ?ArchiveInfo = null,
    total_input: u64 = 0,
    logical_offset: u64 = 0,
    total_output: u64 = 0,
    padding_bytes: u64 = 0,
    finish_requested: bool = false,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        logical_offset: u64,
        output_written: u64,
        padding_bytes: u64,
        member_count: usize,
        member_start: u64,
        pending_replay_bytes: usize,
        finish_requested: bool,
        active: auto_reader.Reader.Snapshot,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        if (options.decoder_input_chunk_size == 0 or options.max_replay_size == 0)
            return error.InvalidCpioMixedReaderState;
        var auto_options = options.auto;
        auto_options.member_mode = true;
        return .{
            .allocator = allocator,
            .options = options,
            .auto = auto_reader.Reader.initWithOptions(allocator, auto_options),
        };
    }

    pub fn deinit(self: *Self) void {
        self.auto.deinit();
        self.replay.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .logical_offset = self.logical_offset,
            .output_written = self.total_output,
            .padding_bytes = self.padding_bytes,
            .member_count = self.member_count,
            .member_start = self.member_start,
            .pending_replay_bytes = self.replay.items.len - self.replay_offset,
            .finish_requested = self.finish_requested,
            .active = self.auto.snapshot(),
        };
    }

    pub fn currentEntry(self: *const Self) ?cpio_reader.EntryInfo {
        return if (self.phase == .member) self.auto.currentEntry() else null;
    }

    pub fn lastArchive(self: *const Self) ?ArchiveInfo {
        return self.last_archive;
    }

    pub fn finish(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.CpioMixedReaderPoisoned;
        if (self.phase == .done) return;
        self.finish_requested = true;
        if (self.phase == .padding and !self.hasReplay()) {
            self.phase = .done;
        } else if (self.phase == .member and !self.hasReplay()) {
            try self.auto.finish();
        }
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.CpioMixedReaderPoisoned;
        if (self.finish_requested and input.len != 0) return error.TrailingData;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .done) {
            if (input.len != 0 or self.hasReplay()) return error.TrailingData;
            return .{ .status = .done };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .padding => {
                while (true) {
                    if (self.hasReplay()) {
                        if (self.replay.items[self.replay_offset] != 0) break;
                        self.replay_offset += 1;
                        try self.recordLogicalPadding(1);
                        if (!self.hasReplay()) self.clearReplay();
                        continue;
                    }
                    if (input_read == input.len) {
                        if (self.finish_requested) {
                            self.phase = .done;
                            return result(input_read, output_written, .done);
                        }
                        return result(input_read, output_written, .need_input);
                    }
                    if (input[input_read] != 0) break;
                    input_read += 1;
                    try self.recordExternalInput(1);
                    try self.recordLogicalPadding(1);
                }
                if (self.member_count == self.options.max_members)
                    return error.OutputLimitExceeded;
                self.auto.reset();
                self.member_start = self.logical_offset;
                self.last_archive = null;
                self.phase = .member;
            },
            .member => {
                const from_replay = self.hasReplay();
                const source = if (from_replay)
                    self.replay.items[self.replay_offset..]
                else
                    input[input_read..][0..@min(
                        input.len - input_read,
                        self.options.decoder_input_chunk_size,
                    )];
                const stepped = try self.auto.step(source, output[output_written..]);
                if (from_replay) {
                    self.replay_offset += stepped.input_read;
                } else {
                    input_read += stepped.input_read;
                    try self.recordExternalInput(stepped.input_read);
                }
                self.logical_offset = std.math.add(
                    u64,
                    self.logical_offset,
                    stepped.input_read,
                ) catch return error.IntegerOverflow;
                output_written += stepped.output_written;
                try self.recordOutput(stepped.output_written);
                switch (stepped.status) {
                    .entry_header => {
                        const entry = self.auto.currentEntry() orelse
                            return error.InvalidCpioMixedReaderState;
                        const pledged = std.math.add(
                            u64,
                            self.total_output,
                            entry.stored_size,
                        ) catch return error.IntegerOverflow;
                        if (pledged > self.options.max_total_output_size)
                            return error.OutputLimitExceeded;
                        return result(input_read, output_written, .entry_header);
                    },
                    .entry_done => return result(input_read, output_written, .entry_done),
                    .done => {
                        const trailing = self.auto.trailingInput();
                        if (trailing.len > self.logical_offset - self.member_start)
                            return error.InvalidCpioMixedReaderState;
                        self.logical_offset -= trailing.len;
                        const raw_snapshot = self.auto.cpioSnapshot() orelse
                            return error.InvalidCpioMixedReaderState;
                        const format = self.auto.detectedFormat() orelse
                            return error.InvalidCpioMixedReaderState;
                        const remaining_replay = if (from_replay)
                            self.replay.items[self.replay_offset..]
                        else
                            &.{};
                        try self.replaceReplay(trailing, remaining_replay);
                        self.last_archive = .{
                            .index = self.member_count,
                            .format = format,
                            .input_offset = self.member_start,
                            .input_size = self.logical_offset - self.member_start,
                            .entry_count = raw_snapshot.entry_count,
                            .output_size = raw_snapshot.output_written,
                            .recovered_suffix_size = trailing.len,
                        };
                        self.member_count = std.math.add(
                            usize,
                            self.member_count,
                            1,
                        ) catch return error.IntegerOverflow;
                        self.phase = .padding;
                        return result(input_read, output_written, .archive_done);
                    },
                    .need_output => return result(input_read, output_written, .need_output),
                    .need_input => {
                        if (from_replay) {
                            if (!self.hasReplay()) {
                                self.clearReplay();
                                continue;
                            }
                            if (stepped.input_read == 0 and stepped.output_written == 0)
                                return error.InvalidCpioMixedReaderState;
                            continue;
                        }
                        if (input_read != input.len) {
                            if (stepped.input_read == 0 and stepped.output_written == 0)
                                return error.InvalidCpioMixedReaderState;
                            continue;
                        }
                        if (self.finish_requested) {
                            if (!self.auto.snapshot().finish_requested) {
                                try self.auto.finish();
                                continue;
                            }
                            return error.TruncatedFrame;
                        }
                        return result(input_read, output_written, .need_input);
                    },
                }
            },
            .done, .poisoned => unreachable,
        };
    }

    fn hasReplay(self: *const Self) bool {
        return self.replay_offset != self.replay.items.len;
    }

    fn clearReplay(self: *Self) void {
        self.replay.clearRetainingCapacity();
        self.replay_offset = 0;
    }

    fn replaceReplay(self: *Self, trailing: []const u8, remaining: []const u8) Error!void {
        const total = std.math.add(usize, trailing.len, remaining.len) catch
            return error.IntegerOverflow;
        if (total > self.options.max_replay_size) return error.OutputLimitExceeded;
        var next: std.ArrayList(u8) = .empty;
        errdefer next.deinit(self.allocator);
        try next.ensureTotalCapacityPrecise(self.allocator, total);
        try next.appendSlice(self.allocator, trailing);
        try next.appendSlice(self.allocator, remaining);
        self.replay.deinit(self.allocator);
        self.replay = next;
        self.replay_offset = 0;
    }

    fn recordExternalInput(self: *Self, count: usize) Error!void {
        self.total_input = std.math.add(u64, self.total_input, count) catch
            return error.IntegerOverflow;
        if (self.total_input > self.options.max_total_input_size)
            return error.OutputLimitExceeded;
    }

    fn recordLogicalPadding(self: *Self, count: usize) Error!void {
        self.padding_bytes = std.math.add(u64, self.padding_bytes, count) catch
            return error.IntegerOverflow;
        if (self.padding_bytes > self.options.max_padding_size)
            return error.OutputLimitExceeded;
        self.logical_offset = std.math.add(u64, self.logical_offset, count) catch
            return error.IntegerOverflow;
    }

    fn recordOutput(self: *Self, count: usize) Error!void {
        self.total_output = std.math.add(u64, self.total_output, count) catch
            return error.IntegerOverflow;
        if (self.total_output > self.options.max_total_output_size)
            return error.OutputLimitExceeded;
    }
};

fn result(input_read: usize, output_written: usize, status: Status) StepResult {
    return .{
        .input_read = input_read,
        .output_written = output_written,
        .status = status,
    };
}
