//! Bounded reader for concatenated raw CPIO archives and initramfs padding.

const std = @import("std");
const archive = @import("archive.zig");
const raw_reader = @import("incremental_reader.zig");

pub const Error = raw_reader.Error || error{
    CpioSequenceReaderPoisoned,
};

pub const Options = struct {
    cpio: raw_reader.Options = .{},
    max_archives: usize = std.math.maxInt(usize),
    max_padding_size: u64 = std.math.maxInt(u64),
    max_total_input_size: u64 = std.math.maxInt(u64),
    max_total_output_size: u64 = std.math.maxInt(u64),
};

pub const Phase = enum { padding, archive, done, poisoned };

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
    format: archive.Format,
    input_offset: u64,
    input_size: u64,
    entry_count: usize,
    output_size: usize,
};

pub const Reader = struct {
    options: Options,
    cpio: raw_reader.Reader,
    phase: Phase = .padding,
    archive_count: usize = 0,
    archive_start: u64 = 0,
    last_archive: ?ArchiveInfo = null,
    total_input: u64 = 0,
    total_output: u64 = 0,
    padding_bytes: u64 = 0,
    input_finished: bool = false,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: u64,
        padding_bytes: u64,
        archive_count: usize,
        archive_start: u64,
        input_finished: bool,
        cpio: raw_reader.Reader.Snapshot,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
        var raw_options = options.cpio;
        raw_options.stop_after_trailer = true;
        return .{
            .options = options,
            .cpio = raw_reader.Reader.initWithOptions(allocator, raw_options),
        };
    }

    pub fn deinit(self: *Self) void {
        self.cpio.deinit();
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .padding_bytes = self.padding_bytes,
            .archive_count = self.archive_count,
            .archive_start = self.archive_start,
            .input_finished = self.input_finished,
            .cpio = self.cpio.snapshot(),
        };
    }

    pub fn currentEntry(self: *const Self) ?raw_reader.EntryInfo {
        return if (self.phase == .archive) self.cpio.currentEntry() else null;
    }

    pub fn lastArchive(self: *const Self) ?ArchiveInfo {
        return self.last_archive;
    }

    /// Marks physical EOF. EOF is valid only between archives; an active
    /// member without `TRAILER!!!` remains a truncation error.
    pub fn finish(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.CpioSequenceReaderPoisoned;
        if (self.phase == .done) {
            self.input_finished = true;
            return;
        }
        if (self.phase != .padding) {
            self.cpio.finish() catch |err| {
                self.phase = .poisoned;
                return err;
            };
            self.phase = .poisoned;
            return error.TruncatedFrame;
        }
        self.input_finished = true;
        self.phase = .done;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.CpioSequenceReaderPoisoned;
        if (self.input_finished and input.len != 0) return error.TrailingData;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .padding => {
                const start = input_read;
                while (input_read < input.len and input[input_read] == 0) : (input_read += 1) {}
                const count = input_read - start;
                try self.recordPadding(count);
                if (input_read == input.len)
                    return result(input_read, output_written, .need_input);
                if (self.archive_count == self.options.max_archives)
                    return error.OutputLimitExceeded;
                self.cpio.reset();
                self.archive_start = self.total_input;
                self.last_archive = null;
                self.phase = .archive;
            },
            .archive => {
                const stepped = try self.cpio.step(
                    input[input_read..],
                    output[output_written..],
                );
                input_read += stepped.input_read;
                try self.recordInput(stepped.input_read);
                output_written += stepped.output_written;
                try self.recordOutput(stepped.output_written);
                switch (stepped.status) {
                    .entry_header => {
                        const entry = self.cpio.currentEntry() orelse
                            return error.InvalidCpioArchive;
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
                        const raw_snapshot = self.cpio.snapshot();
                        const format = raw_snapshot.format orelse
                            return error.InvalidCpioArchive;
                        const input_size = self.total_input - self.archive_start;
                        self.last_archive = .{
                            .index = self.archive_count,
                            .format = format,
                            .input_offset = self.archive_start,
                            .input_size = input_size,
                            .entry_count = raw_snapshot.entry_count,
                            .output_size = raw_snapshot.output_written,
                        };
                        self.archive_count = std.math.add(
                            usize,
                            self.archive_count,
                            1,
                        ) catch return error.IntegerOverflow;
                        self.phase = .padding;
                        return result(input_read, output_written, .archive_done);
                    },
                    .need_output => return result(input_read, output_written, .need_output),
                    .need_input => {
                        if (input_read != input.len) {
                            if (stepped.input_read == 0 and stepped.output_written == 0)
                                return error.InvalidCpioArchive;
                            continue;
                        }
                        return result(input_read, output_written, .need_input);
                    },
                }
            },
            .done, .poisoned => unreachable,
        };
    }

    fn recordPadding(self: *Self, count: usize) Error!void {
        const amount: u64 = @intCast(count);
        self.padding_bytes = std.math.add(u64, self.padding_bytes, amount) catch
            return error.IntegerOverflow;
        if (self.padding_bytes > self.options.max_padding_size)
            return error.OutputLimitExceeded;
        try self.addTotalInput(amount);
    }

    fn recordInput(self: *Self, count: usize) Error!void {
        try self.addTotalInput(@intCast(count));
    }

    fn addTotalInput(self: *Self, count: u64) Error!void {
        self.total_input = std.math.add(u64, self.total_input, count) catch
            return error.IntegerOverflow;
        if (self.total_input > self.options.max_total_input_size)
            return error.OutputLimitExceeded;
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
