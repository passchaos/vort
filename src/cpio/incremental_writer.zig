//! Bounded caller-output CPIO writer for every supported header family.

const std = @import("std");
const archive = @import("archive.zig");
const wire = @import("wire.zig");

pub const Error = wire.Error || error{
    InvalidCpioWriterState,
    CpioWriterPoisoned,
};

pub const Options = struct {
    format: archive.Format = .newc,
    block_size: usize = 512,
    max_entries: usize = std.math.maxInt(usize),
    max_control_record_size: usize = 16 * 1024 * 1024,
    max_entry_size: usize = std.math.maxInt(usize),
    max_total_input: u64 = std.math.maxInt(u64),
    max_archive_size: u64 = std.math.maxInt(u64),
};

/// Metadata for one streamed member. `size` is mandatory because all CPIO
/// header families place it before the payload. SVR4 CRC additionally requires
/// `checksum` for non-empty data; the writer verifies it while copying bytes.
pub const EntryOptions = struct {
    name: []const u8,
    size: usize = 0,
    kind: archive.Kind = .regular,
    permissions: ?u16 = null,
    inode: ?u32 = null,
    link_count: u32 = 1,
    uid: u32 = 0,
    gid: u32 = 0,
    mtime: u32 = 0,
    device_major: u32 = 0,
    device_minor: u32 = 0,
    rdevice_major: u32 = 0,
    rdevice_minor: u32 = 0,
    checksum: ?u32 = null,
};

pub const Phase = enum {
    ready,
    entry_header,
    entry_data,
    entry_padding,
    archive_end,
    done,
    poisoned,
};

pub const Status = enum {
    need_input,
    need_output,
    entry_done,
    done,
};

pub const StepResult = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    status: Status,
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .ready,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    current: ?CurrentEntry = null,
    entry_count: usize = 0,
    archive_output: u64 = 0,
    total_input: u64 = 0,
    finish_entry_requested: bool = false,
    finish_archive_requested: bool = false,

    const Self = @This();

    const CurrentEntry = struct {
        expected_input: usize,
        input_read: usize = 0,
        padding_remaining: usize,
        expected_checksum: ?u32,
        checksum: u32 = 0,
        allow_zero_symlink_checksum: bool,
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: u64,
        entry_count: usize,
        current_input_read: usize,
        current_expected_input: usize,
        current_checksum: u32,
        pending_output: usize,
        finish_entry_requested: bool,
        finish_archive_requested: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        if (options.block_size > 1024 * 1024 or options.max_control_record_size == 0)
            return error.InvalidCpioOptions;
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Self) void {
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.archive_output,
            .entry_count = self.entry_count,
            .current_input_read = if (self.current) |entry| entry.input_read else 0,
            .current_expected_input = if (self.current) |entry| entry.expected_input else 0,
            .current_checksum = if (self.current) |entry| entry.checksum else 0,
            .pending_output = self.pending.items.len - self.pending_offset,
            .finish_entry_requested = self.finish_entry_requested,
            .finish_archive_requested = self.finish_archive_requested,
        };
    }

    pub fn beginEntry(self: *Self, entry: EntryOptions) Error!void {
        if (self.phase == .poisoned) return error.CpioWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidCpioWriterState;
        if (self.entry_count == self.options.max_entries or
            entry.size > self.options.max_entry_size)
        {
            return error.OutputLimitExceeded;
        }
        try wire.validateName(entry.name);
        try wire.validateDataKind(entry.kind, entry.size);
        if (entry.link_count == 0) return error.InvalidCpioOptions;

        const wire_checksum: u32 = switch (self.options.format) {
            .crc => entry.checksum orelse if (entry.size == 0)
                0
            else
                return error.InvalidCpioOptions,
            else => checksum: {
                if (entry.checksum != null) return error.InvalidCpioOptions;
                break :checksum 0;
            },
        };
        const default_inode = std.math.add(usize, self.entry_count, 1) catch
            return error.IntegerOverflow;
        const inode = entry.inode orelse
            (std.math.cast(u32, default_inode) orelse return error.CpioFieldOverflow);

        const prefix_len = try wire.entryPrefixLen(
            self.archive_output,
            entry.name.len,
            self.options.format,
        );
        if (prefix_len > self.options.max_control_record_size)
            return error.OutputLimitExceeded;

        var prepared: std.ArrayList(u8) = .empty;
        errdefer prepared.deinit(self.allocator);
        try prepared.ensureTotalCapacity(self.allocator, prefix_len);
        try wire.appendEntryPrefix(
            self.allocator,
            &prepared,
            self.archive_output,
            entry.name,
            entry.size,
            wire_checksum,
            .{
                .inode = inode,
                .mode = try wire.modeFor(entry.kind, entry.permissions),
                .uid = entry.uid,
                .gid = entry.gid,
                .link_count = entry.link_count,
                .mtime = entry.mtime,
                .device_major = entry.device_major,
                .device_minor = entry.device_minor,
                .rdevice_major = entry.rdevice_major,
                .rdevice_minor = entry.rdevice_minor,
            },
            self.options.format,
        );
        std.debug.assert(prepared.items.len == prefix_len);

        const prefix_end = try checkedAddU64(
            self.archive_output,
            @intCast(prepared.items.len),
        );
        const data_end = try checkedAddU64(prefix_end, @intCast(entry.size));
        const padding = wire.paddingForU64(data_end, wire.dataAlignment(self.options.format));
        const entry_end = try checkedAddU64(data_end, @intCast(padding));
        if (entry_end > self.options.max_archive_size) return error.OutputLimitExceeded;

        self.pending.deinit(self.allocator);
        self.pending = prepared;
        self.pending_offset = 0;
        self.current = .{
            .expected_input = entry.size,
            .padding_remaining = padding,
            .expected_checksum = if (self.options.format == .crc) wire_checksum else null,
            .allow_zero_symlink_checksum = self.options.format == .crc and
                entry.kind == .symlink and wire_checksum == 0,
        };
        self.finish_entry_requested = false;
        self.phase = .entry_header;
    }

    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.CpioWriterPoisoned;
        if (self.phase != .entry_header and self.phase != .entry_data)
            return error.InvalidCpioWriterState;
        if (self.finish_entry_requested) return error.InvalidCpioWriterState;
        const entry = self.current.?;
        if (entry.input_read != entry.expected_input) return error.SizeMismatch;
        if (entry.expected_checksum) |expected| {
            if (!entry.allow_zero_symlink_checksum and entry.checksum != expected) {
                self.phase = .poisoned;
                return error.ChecksumMismatch;
            }
        }
        self.finish_entry_requested = true;
    }

    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.CpioWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidCpioWriterState;

        const trailer_prefix_len = try wire.entryPrefixLen(
            self.archive_output,
            archive.trailer_name.len,
            self.options.format,
        );
        const trailer_end = try checkedAddU64(
            self.archive_output,
            @intCast(trailer_prefix_len),
        );
        const final_padding = wire.paddingForU64(trailer_end, self.options.block_size);
        const ending_len = std.math.add(usize, trailer_prefix_len, final_padding) catch
            return error.IntegerOverflow;
        if (ending_len > self.options.max_control_record_size)
            return error.OutputLimitExceeded;
        const archive_end = try checkedAddU64(self.archive_output, @intCast(ending_len));
        if (archive_end > self.options.max_archive_size) return error.OutputLimitExceeded;

        var ending: std.ArrayList(u8) = .empty;
        errdefer ending.deinit(self.allocator);
        try ending.ensureTotalCapacity(self.allocator, ending_len);
        try wire.appendEntryPrefix(
            self.allocator,
            &ending,
            self.archive_output,
            archive.trailer_name,
            0,
            0,
            .{
                .inode = 0,
                .mode = 0,
                .uid = 0,
                .gid = 0,
                .link_count = 1,
                .mtime = 0,
                .device_major = 0,
                .device_minor = 0,
                .rdevice_major = 0,
                .rdevice_minor = 0,
            },
            self.options.format,
        );
        try wire.appendPadding(self.allocator, &ending, final_padding);
        std.debug.assert(ending.items.len == ending_len);

        self.pending.deinit(self.allocator);
        self.pending = ending;
        self.pending_offset = 0;
        self.finish_archive_requested = true;
        self.phase = .archive_end;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.CpioWriterPoisoned;
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
            .ready => {
                if (input_read != input.len) return error.InvalidCpioWriterState;
                return result(input_read, output_written, .need_input);
            },
            .entry_header, .archive_end => {
                try self.drainPending(output, &output_written);
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (self.phase == .archive_end) {
                    self.phase = .done;
                    return result(input_read, output_written, .done);
                }
                self.phase = .entry_data;
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
            },
            .entry_data => {
                var entry = &self.current.?;
                if (input_read != input.len) {
                    if (entry.input_read == entry.expected_input)
                        return result(input_read, output_written, .need_input);
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    const entry_remaining = entry.expected_input - entry.input_read;
                    const take = @min(
                        entry_remaining,
                        @min(input.len - input_read, output.len - output_written),
                    );
                    try self.checkInputAddition(take);
                    const allowed = self.limitArchiveWrite(take);
                    if (allowed == 0) return error.OutputLimitExceeded;
                    const source = input[input_read..][0..allowed];
                    @memcpy(output[output_written..][0..allowed], source);
                    entry.checksum = addByteSum(entry.checksum, source);
                    entry.input_read += allowed;
                    input_read += allowed;
                    output_written += allowed;
                    self.total_input += @intCast(allowed);
                    self.archive_output += @intCast(allowed);
                    if (allowed != take or output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    continue;
                }
                if (!self.finish_entry_requested)
                    return result(input_read, output_written, .need_input);
                self.phase = .entry_padding;
            },
            .entry_padding => {
                var entry = &self.current.?;
                const take = @min(entry.padding_remaining, output.len - output_written);
                const allowed = self.limitArchiveWrite(take);
                if (allowed == 0 and entry.padding_remaining != 0) {
                    if (output_written == output.len)
                        return result(input_read, output_written, .need_output);
                    return error.OutputLimitExceeded;
                }
                @memset(output[output_written..][0..allowed], 0);
                entry.padding_remaining -= allowed;
                output_written += allowed;
                self.archive_output += @intCast(allowed);
                if (entry.padding_remaining != 0)
                    return result(input_read, output_written, .need_output);
                self.current = null;
                self.entry_count += 1;
                self.finish_entry_requested = false;
                self.phase = .ready;
                return result(input_read, output_written, .entry_done);
            },
            .done => unreachable,
            .poisoned => return error.CpioWriterPoisoned,
        };
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) Error!void {
        const remaining = self.pending.items[self.pending_offset..];
        const wanted = @min(remaining.len, output.len - output_written.*);
        const take = self.limitArchiveWrite(wanted);
        if (take == 0 and remaining.len != 0) {
            if (output_written.* == output.len) return;
            return error.OutputLimitExceeded;
        }
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        self.archive_output += @intCast(take);
    }

    fn checkInputAddition(self: *const Self, amount: usize) Error!void {
        const next = try checkedAddU64(self.total_input, @intCast(amount));
        if (next > self.options.max_total_input) return error.OutputLimitExceeded;
    }

    fn limitArchiveWrite(self: *const Self, wanted: usize) usize {
        const remaining = self.options.max_archive_size -| self.archive_output;
        return @min(wanted, std.math.cast(usize, remaining) orelse std.math.maxInt(usize));
    }
};

fn addByteSum(initial: u32, bytes: []const u8) u32 {
    var sum = initial;
    for (bytes) |byte| sum +%= byte;
    return sum;
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
