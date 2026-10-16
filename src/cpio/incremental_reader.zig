//! Bounded caller-output CPIO reader for every supported header family.

const std = @import("std");
const archive = @import("archive.zig");

pub const Error = archive.Error || std.mem.Allocator.Error || error{CpioReaderPoisoned};

pub const Options = struct {
    max_entries: usize = std.math.maxInt(usize),
    max_control_record_size: usize = 16 * 1024 * 1024,
    max_name_size: usize = 16 * 1024 * 1024,
    max_entry_size: usize = std.math.maxInt(usize),
    max_total_output_size: usize = std.math.maxInt(usize),
    max_archive_size: u64 = std.math.maxInt(u64),
};

pub const Phase = enum {
    header,
    name,
    name_padding,
    entry_header,
    entry_data,
    entry_padding,
    archive_padding,
    done,
    poisoned,
};

pub const Status = enum {
    need_input,
    need_output,
    entry_header,
    entry_done,
    done,
};

pub const StepResult = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    status: Status,
};

/// `name` borrows reader-owned memory. It remains valid through the entry's
/// payload and is released when the corresponding `.entry_done` is returned.
pub const EntryInfo = struct {
    name: []const u8,
    format: archive.Format,
    kind: archive.Kind,
    mode: u32,
    inode: u32,
    uid: u32,
    gid: u32,
    link_count: u32,
    mtime: u32,
    device_major: u32,
    device_minor: u32,
    rdevice_major: u32,
    rdevice_minor: u32,
    checksum: ?u32,
    stored_size: usize,
    header_offset: u64,
    data_offset: u64,
    safe_path: bool,

    pub fn isExtractable(self: EntryInfo) bool {
        return self.kind == .regular or self.kind == .symlink;
    }
};

const CurrentEntry = struct {
    info: EntryInfo,
    data_read: usize = 0,
    checksum: u32 = 0,
    padding_remaining: usize,
};

pub const Reader = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    format: ?archive.Format = null,
    header: [archive.newc_header_size]u8 = undefined,
    header_len: usize = 0,
    header_expected: usize = 0,
    header_offset: u64 = 0,
    fixed: ?archive.FixedHeader = null,
    name: std.ArrayList(u8) = .empty,
    name_padding_remaining: usize = 0,
    current: ?CurrentEntry = null,
    entry_count: usize = 0,
    total_input: u64 = 0,
    total_output: usize = 0,
    input_finished: bool = false,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        format: ?archive.Format,
        input_read: u64,
        output_written: usize,
        entry_count: usize,
        header_received: usize,
        header_expected: usize,
        name_received: usize,
        name_expected: usize,
        current_data_read: usize,
        current_stored_size: usize,
        current_checksum: u32,
        retained_name_capacity: usize,
        input_finished: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Self) void {
        self.name.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Self) void {
        self.phase = .header;
        self.format = null;
        self.header_len = 0;
        self.header_expected = 0;
        self.header_offset = 0;
        self.fixed = null;
        self.name.clearRetainingCapacity();
        self.name_padding_remaining = 0;
        self.current = null;
        self.entry_count = 0;
        self.total_input = 0;
        self.total_output = 0;
        self.input_finished = false;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .format = self.format,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .entry_count = self.entry_count,
            .header_received = self.header_len,
            .header_expected = self.header_expected,
            .name_received = self.name.items.len,
            .name_expected = if (self.fixed) |fixed| fixed.name_size else 0,
            .current_data_read = if (self.current) |entry| entry.data_read else 0,
            .current_stored_size = if (self.current) |entry| entry.info.stored_size else 0,
            .current_checksum = if (self.current) |entry| entry.checksum else 0,
            .retained_name_capacity = self.name.capacity,
            .input_finished = self.input_finished,
        };
    }

    pub fn currentEntry(self: *const Self) ?EntryInfo {
        return if (self.current) |current| current.info else null;
    }

    /// Marks physical EOF. A valid CPIO stream must already have parsed its
    /// `TRAILER!!!` record; any bytes following it must have been zero.
    pub fn finish(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.CpioReaderPoisoned;
        if (self.phase == .done) {
            self.input_finished = true;
            return;
        }
        if (self.phase != .archive_padding) {
            self.phase = .poisoned;
            return error.TruncatedFrame;
        }
        self.input_finished = true;
        self.phase = .done;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.CpioReaderPoisoned;
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
            .header => {
                if (self.header_len == 0) self.header_offset = self.total_input;
                if (self.header_expected == 0) {
                    if (self.header_len < 2 and
                        !try self.fillHeaderTo(input, &input_read, 2))
                    {
                        return result(input_read, output_written, .need_input);
                    }
                    const detected = archive.detectFormat(
                        self.header[0..self.header_len],
                        0,
                    ) catch |err| switch (err) {
                        error.TruncatedFrame => incomplete: {
                            if (self.header_len < 6 and
                                !try self.fillHeaderTo(input, &input_read, 6))
                            {
                                return result(input_read, output_written, .need_input);
                            }
                            break :incomplete try archive.detectFormat(
                                self.header[0..self.header_len],
                                0,
                            );
                        },
                        else => return err,
                    };
                    if (self.format) |format| {
                        if (detected != format) return error.InvalidCpioArchive;
                    } else {
                        self.format = detected;
                    }
                    self.header_expected = archive.fixedHeaderSize(detected);
                }
                if (!try self.fillHeaderTo(input, &input_read, self.header_expected))
                    return result(input_read, output_written, .need_input);
                const fixed = try archive.parseFixedHeader(
                    self.header[0..self.header_expected],
                    self.format.?,
                );
                if (fixed.name_size < 2) return error.InvalidCpioArchive;
                const plain_name_size = fixed.name_size - 1;
                if (plain_name_size > self.options.max_name_size)
                    return error.OutputLimitExceeded;
                const prefix_unaligned = std.math.add(
                    usize,
                    fixed.header_size,
                    fixed.name_size,
                ) catch return error.IntegerOverflow;
                const prefix_end = try checkedAddU64(
                    self.header_offset,
                    @intCast(prefix_unaligned),
                );
                const prefix_padding = paddingForU64(prefix_end, fixed.alignment);
                const control_size = std.math.add(
                    usize,
                    prefix_unaligned,
                    prefix_padding,
                ) catch return error.IntegerOverflow;
                if (control_size > self.options.max_control_record_size)
                    return error.OutputLimitExceeded;
                self.name.clearRetainingCapacity();
                try self.name.ensureTotalCapacityPrecise(self.allocator, fixed.name_size);
                self.fixed = fixed;
                self.phase = .name;
            },
            .name => {
                const expected = self.fixed.?.name_size;
                const take = @min(expected - self.name.items.len, input.len - input_read);
                try self.recordInput(take);
                try self.name.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                if (self.name.items.len != expected)
                    return result(input_read, output_written, .need_input);
                _ = try archive.parseName(self.name.items);
                self.name_padding_remaining = paddingForU64(
                    self.total_input,
                    self.fixed.?.alignment,
                );
                self.phase = .name_padding;
            },
            .name_padding => {
                const take = @min(self.name_padding_remaining, input.len - input_read);
                try requireZero(input[input_read..][0..take]);
                try self.recordInput(take);
                input_read += take;
                self.name_padding_remaining -= take;
                if (self.name_padding_remaining != 0)
                    return result(input_read, output_written, .need_input);
                try self.prepareEntry();
            },
            .entry_header => {
                self.phase = .entry_data;
                return result(input_read, output_written, .entry_header);
            },
            .entry_data => {
                var entry = &self.current.?;
                const remaining = entry.info.stored_size - entry.data_read;
                if (remaining != 0) {
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    if (input_read == input.len)
                        return result(input_read, output_written, .need_input);
                    const take = @min(
                        remaining,
                        @min(input.len - input_read, output.len - output_written),
                    );
                    try self.recordInput(take);
                    const source = input[input_read..][0..take];
                    @memcpy(output[output_written..][0..take], source);
                    entry.checksum = addByteSum(entry.checksum, source);
                    entry.data_read += take;
                    input_read += take;
                    output_written += take;
                    self.total_output += take;
                    continue;
                }
                try validateChecksum(entry.*);
                self.phase = .entry_padding;
            },
            .entry_padding => {
                var entry = &self.current.?;
                const take = @min(entry.padding_remaining, input.len - input_read);
                try requireZero(input[input_read..][0..take]);
                try self.recordInput(take);
                input_read += take;
                entry.padding_remaining -= take;
                if (entry.padding_remaining != 0)
                    return result(input_read, output_written, .need_input);
                self.current = null;
                self.entry_count = std.math.add(usize, self.entry_count, 1) catch
                    return error.IntegerOverflow;
                self.header_len = 0;
                self.header_expected = 0;
                self.fixed = null;
                self.name.clearRetainingCapacity();
                self.phase = .header;
                return result(input_read, output_written, .entry_done);
            },
            .archive_padding => {
                const take = input.len - input_read;
                try requireZero(input[input_read..]);
                try self.recordInput(take);
                input_read += take;
                return result(input_read, output_written, .need_input);
            },
            .done, .poisoned => unreachable,
        };
    }

    fn prepareEntry(self: *Self) Error!void {
        const fixed = self.fixed.?;
        const name = try archive.parseName(self.name.items);
        if (try archive.validateEntryHeader(fixed, name)) {
            self.header_len = 0;
            self.header_expected = 0;
            self.fixed = null;
            self.name.clearRetainingCapacity();
            self.phase = .archive_padding;
            return;
        }
        if (self.entry_count == self.options.max_entries or
            fixed.stored_size > self.options.max_entry_size)
        {
            return error.OutputLimitExceeded;
        }
        const next_output = std.math.add(
            usize,
            self.total_output,
            fixed.stored_size,
        ) catch return error.IntegerOverflow;
        if (next_output > self.options.max_total_output_size)
            return error.OutputLimitExceeded;
        const data_end = try checkedAddU64(self.total_input, @intCast(fixed.stored_size));
        const padding = paddingForU64(data_end, fixed.alignment);
        const entry_end = try checkedAddU64(data_end, @intCast(padding));
        if (entry_end > self.options.max_archive_size)
            return error.OutputLimitExceeded;

        self.current = .{
            .info = .{
                .name = name,
                .format = fixed.format,
                .kind = fixed.kind,
                .mode = fixed.mode,
                .inode = fixed.inode,
                .uid = fixed.uid,
                .gid = fixed.gid,
                .link_count = fixed.link_count,
                .mtime = fixed.mtime,
                .device_major = fixed.device_major,
                .device_minor = fixed.device_minor,
                .rdevice_major = fixed.rdevice_major,
                .rdevice_minor = fixed.rdevice_minor,
                .checksum = fixed.checksum,
                .stored_size = fixed.stored_size,
                .header_offset = self.header_offset,
                .data_offset = self.total_input,
                .safe_path = archive.isSafePath(name),
            },
            .padding_remaining = padding,
        };
        self.phase = .entry_header;
    }

    fn fillHeaderTo(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        target: usize,
    ) Error!bool {
        const take = @min(target - self.header_len, input.len - input_read.*);
        try self.recordInput(take);
        @memcpy(
            self.header[self.header_len..][0..take],
            input[input_read.*..][0..take],
        );
        self.header_len += take;
        input_read.* += take;
        return self.header_len == target;
    }

    fn recordInput(self: *Self, count: usize) Error!void {
        const next = try checkedAddU64(self.total_input, @intCast(count));
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
        self.total_input = next;
    }
};

fn validateChecksum(entry: CurrentEntry) Error!void {
    if (entry.info.checksum) |expected| {
        if (!(entry.info.kind == .symlink and expected == 0) and
            entry.checksum != expected)
        {
            return error.ChecksumMismatch;
        }
    }
}

fn addByteSum(initial: u32, bytes: []const u8) u32 {
    var sum = initial;
    for (bytes) |byte| sum +%= byte;
    return sum;
}

fn requireZero(bytes: []const u8) Error!void {
    for (bytes) |byte|
        if (byte != 0) return error.InvalidCpioArchive;
}

fn paddingForU64(offset: u64, alignment: usize) usize {
    if (alignment <= 1) return 0;
    const alignment_u64: u64 = @intCast(alignment);
    return @intCast((alignment_u64 - offset % alignment_u64) % alignment_u64);
}

fn checkedAddU64(a: u64, b: u64) Error!u64 {
    return std.math.add(u64, a, b) catch error.IntegerOverflow;
}

fn result(input_read: usize, output_written: usize, status: Status) StepResult {
    return .{
        .input_read = input_read,
        .output_written = output_written,
        .status = status,
    };
}
