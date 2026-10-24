//! Bounded caller-output TAR writer.

const std = @import("std");
const archive = @import("archive.zig");
const wire = @import("wire.zig");

pub const Error = archive.Error || wire.Error || std.mem.Allocator.Error || error{
    InvalidTarEntryName,
    InvalidTarWriterState,
    NonZeroSparseHole,
    OutputLimitExceeded,
    SizeMismatch,
    TarWriterPoisoned,
};

pub const SparseExtent = wire.SparseExtent;
pub const SparseWriteFormat = wire.SparseWriteFormat;

pub const SparseOptions = struct {
    logical_size: usize,
    extents: []const SparseExtent,
    format: SparseWriteFormat = .pax_1_0,
};

pub const EntryOptions = struct {
    name: []const u8,
    kind: archive.Kind = .file,
    link_name: []const u8 = "",
    size: usize = 0,
    mode: u32 = 0,
    mtime: u64 = 0,
    sparse: ?SparseOptions = null,
};

pub const Options = struct {
    max_entries: usize = std.math.maxInt(usize),
    max_control_record_size: usize = 16 * 1024 * 1024,
    max_logical_entry_size: usize = std.math.maxInt(usize),
    max_sparse_extents: usize = 1024 * 1024,
    max_archive_size: u64 = std.math.maxInt(u64),
    validate_sparse_holes: bool = true,
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

const DataProgress = struct {
    input_read: usize,
    output_written: usize,
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
        sparse: ?SparseState = null,

        const SparseState = struct {
            normalized: []wire.SparseExtent,
            extent_index: usize = 0,
            logical_offset: usize = 0,
        };

        fn deinit(self: *CurrentEntry, allocator: std.mem.Allocator) void {
            if (self.sparse) |state| allocator.free(state.normalized);
            self.* = undefined;
        }
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: u64,
        entry_count: usize,
        current_input_read: usize,
        current_expected_input: usize,
        pending_output: usize,
        finish_entry_requested: bool,
        finish_archive_requested: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.archive_output,
            .entry_count = self.entry_count,
            .current_input_read = if (self.current) |entry| entry.input_read else 0,
            .current_expected_input = if (self.current) |entry| entry.expected_input else 0,
            .pending_output = self.pending.items.len - self.pending_offset,
            .finish_entry_requested = self.finish_entry_requested,
            .finish_archive_requested = self.finish_archive_requested,
        };
    }

    pub fn deinit(self: *Self) void {
        if (self.current) |*entry| entry.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn beginEntry(self: *Self, entry: EntryOptions) Error!void {
        if (self.phase == .poisoned) return error.TarWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidTarWriterState;
        try self.validateEntry(entry);
        if (self.entry_count == self.options.max_entries)
            return error.OutputLimitExceeded;

        var sparse_state: ?CurrentEntry.SparseState = null;
        errdefer if (sparse_state) |state| self.allocator.free(state.normalized);
        var prepared: std.ArrayList(u8) = .empty;
        errdefer prepared.deinit(self.allocator);
        const expected_input: usize = if (entry.sparse) |sparse_options| sparse_options.logical_size else entry.size;
        const stored_size: usize = if (entry.sparse) |sparse_options| sparse_size: {
            const normalized = try wire.normalizeSparseExtentsAlloc(
                self.allocator,
                sparse_options.logical_size,
                sparse_options.extents,
            );
            sparse_state = .{ .normalized = normalized };
            const physical_size = switch (sparse_options.format) {
                .pax_1_0 => try wire.appendPaxSparsePrefix(
                    self.allocator,
                    &prepared,
                    entry.name,
                    effectiveMode(entry),
                    entry.mtime,
                    sparse_options.logical_size,
                    normalized,
                ),
                .gnu_old => try wire.appendOldGnuSparsePrefix(
                    self.allocator,
                    &prepared,
                    entry.name,
                    effectiveMode(entry),
                    entry.mtime,
                    sparse_options.logical_size,
                    normalized,
                ),
            };
            break :sparse_size physical_size;
        } else regular_size: {
            try appendOrdinaryPrefix(self.allocator, &prepared, entry);
            break :regular_size if (entry.kind == .file) entry.size else 0;
        };
        if (prepared.items.len > self.options.max_control_record_size)
            return error.OutputLimitExceeded;
        try self.checkArchiveAddition(prepared.items.len);

        self.pending.deinit(self.allocator);
        self.pending = prepared;
        self.pending_offset = 0;
        self.current = .{
            .expected_input = expected_input,
            .padding_remaining = paddingFor(stored_size),
            .sparse = sparse_state,
        };
        sparse_state = null;
        self.finish_entry_requested = false;
        self.phase = .entry_header;
    }

    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.TarWriterPoisoned;
        if (self.phase != .entry_header and self.phase != .entry_data)
            return error.InvalidTarWriterState;
        if (self.finish_entry_requested) return error.InvalidTarWriterState;
        if (self.current.?.input_read != self.current.?.expected_input)
            return error.SizeMismatch;
        self.finish_entry_requested = true;
    }

    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.TarWriterPoisoned;
        if (self.phase != .ready or self.finish_archive_requested)
            return error.InvalidTarWriterState;
        try self.checkArchiveAddition(2 * wire.block_size);
        var ending: std.ArrayList(u8) = .empty;
        errdefer ending.deinit(self.allocator);
        try ending.appendNTimes(self.allocator, 0, 2 * wire.block_size);
        self.pending.deinit(self.allocator);
        self.pending = ending;
        self.pending_offset = 0;
        self.finish_archive_requested = true;
        self.phase = .archive_end;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.TarWriterPoisoned;
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
                if (input.len != input_read) return error.InvalidTarWriterState;
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
                const entry = &self.current.?;
                if (input_read < input.len) {
                    if (entry.input_read == entry.expected_input)
                        return result(input_read, output_written, .need_input);
                    const progress = if (entry.sparse != null)
                        try self.stepSparseData(entry, input[input_read..], output[output_written..])
                    else
                        try self.stepRegularData(entry, input[input_read..], output[output_written..]);
                    input_read += progress.input_read;
                    output_written += progress.output_written;
                    if (input_read != input.len)
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
                try self.addArchiveOutput(allowed);
                if (entry.padding_remaining != 0)
                    return result(input_read, output_written, .need_output);
                entry.deinit(self.allocator);
                self.current = null;
                self.entry_count += 1;
                self.finish_entry_requested = false;
                self.phase = .ready;
                return result(input_read, output_written, .entry_done);
            },
            .done, .poisoned => unreachable,
        };
    }

    fn stepRegularData(
        self: *Self,
        entry: *CurrentEntry,
        input: []const u8,
        output: []u8,
    ) Error!DataProgress {
        const remaining = entry.expected_input - entry.input_read;
        const wanted = @min(@min(input.len, output.len), remaining);
        const take = self.limitArchiveWrite(wanted);
        if (take == 0 and input.len != 0 and remaining != 0) {
            if (output.len == 0) return .{ .input_read = 0, .output_written = 0 };
            return error.OutputLimitExceeded;
        }
        @memcpy(output[0..take], input[0..take]);
        entry.input_read += take;
        self.total_input = std.math.add(u64, self.total_input, take) catch
            return error.IntegerOverflow;
        try self.addArchiveOutput(take);
        return .{ .input_read = take, .output_written = take };
    }

    fn stepSparseData(
        self: *Self,
        entry: *CurrentEntry,
        input: []const u8,
        output: []u8,
    ) Error!DataProgress {
        const state = &entry.sparse.?;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (input_read < input.len and state.logical_offset < entry.expected_input) {
            while (state.extent_index < state.normalized.len and
                state.logical_offset == state.normalized[state.extent_index].offset +
                    state.normalized[state.extent_index].len)
                state.extent_index += 1;
            const next = if (state.extent_index < state.normalized.len)
                state.normalized[state.extent_index]
            else
                wire.SparseExtent{ .offset = entry.expected_input, .len = 0 };
            if (state.logical_offset < next.offset) {
                const take = @min(input.len - input_read, next.offset - state.logical_offset);
                if (self.options.validate_sparse_holes)
                    for (input[input_read..][0..take]) |byte|
                        if (byte != 0) return error.NonZeroSparseHole;
                input_read += take;
                state.logical_offset += take;
                entry.input_read += take;
                self.total_input = std.math.add(u64, self.total_input, take) catch
                    return error.IntegerOverflow;
                continue;
            }
            const extent_end = next.offset + next.len;
            const wanted = @min(
                @min(input.len - input_read, output.len - output_written),
                extent_end - state.logical_offset,
            );
            const take = self.limitArchiveWrite(wanted);
            if (take == 0) break;
            @memcpy(output[output_written..][0..take], input[input_read..][0..take]);
            input_read += take;
            output_written += take;
            state.logical_offset += take;
            entry.input_read += take;
            self.total_input = std.math.add(u64, self.total_input, take) catch
                return error.IntegerOverflow;
            try self.addArchiveOutput(take);
        }
        return .{ .input_read = input_read, .output_written = output_written };
    }

    fn validateEntry(self: *const Self, entry: EntryOptions) Error!void {
        if (entry.name.len == 0 or std.mem.indexOfScalar(u8, entry.name, 0) != null or
            std.mem.indexOfScalar(u8, entry.link_name, 0) != null)
            return error.InvalidTarEntryName;
        const metadata_len = std.math.add(usize, entry.name.len, entry.link_name.len) catch
            return error.IntegerOverflow;
        if (metadata_len > self.options.max_control_record_size)
            return error.OutputLimitExceeded;
        if (entry.sparse) |sparse_options| {
            if (entry.kind != .file or entry.link_name.len != 0 or entry.size != 0)
                return error.InvalidTarHeader;
            if (sparse_options.logical_size > self.options.max_logical_entry_size or
                sparse_options.extents.len > self.options.max_sparse_extents)
                return error.OutputLimitExceeded;
            if (sparse_options.format == .gnu_old and entry.name.len > 100)
                return error.InvalidTarEntryName;
            var previous_end: usize = 0;
            for (sparse_options.extents) |extent| {
                const end = std.math.add(usize, extent.offset, extent.len) catch
                    return error.IntegerOverflow;
                if (extent.len == 0 or extent.offset < previous_end or
                    end > sparse_options.logical_size)
                    return error.InvalidTarHeader;
                previous_end = end;
            }
            return;
        }
        if (entry.size > self.options.max_logical_entry_size)
            return error.OutputLimitExceeded;
        switch (entry.kind) {
            .file => if (entry.link_name.len != 0) return error.InvalidTarHeader,
            .directory => if (entry.size != 0 or entry.link_name.len != 0)
                return error.InvalidTarHeader,
            .symbolic_link, .hard_link => if (entry.size != 0 or entry.link_name.len == 0)
                return error.InvalidTarHeader,
            .other => return error.UnsupportedTarEntryType,
        }
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
        try self.addArchiveOutput(take);
    }

    fn checkArchiveAddition(self: *const Self, amount: usize) Error!void {
        const next = std.math.add(u64, self.archive_output, amount) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
    }

    fn addArchiveOutput(self: *Self, amount: usize) Error!void {
        const next = std.math.add(u64, self.archive_output, amount) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
        self.archive_output = next;
    }

    fn limitArchiveWrite(self: *const Self, wanted: usize) usize {
        const remaining = self.options.max_archive_size -| self.archive_output;
        return @min(wanted, std.math.cast(usize, remaining) orelse std.math.maxInt(usize));
    }

    fn result(input_read: usize, output_written: usize, status: Status) StepResult {
        return .{ .input_read = input_read, .output_written = output_written, .status = status };
    }
};

fn appendOrdinaryPrefix(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    entry: EntryOptions,
) !void {
    var pax: std.ArrayList(u8) = .empty;
    defer pax.deinit(allocator);
    if (entry.name.len > 100)
        try wire.appendPaxRecord(allocator, &pax, "path", entry.name);
    if (entry.link_name.len > 100)
        try wire.appendPaxRecord(allocator, &pax, "linkpath", entry.link_name);
    if (pax.items.len != 0) {
        try wire.appendUstarHeader(allocator, output, .{
            .name = "PaxHeaders.X/vort",
            .mode = 0o644,
            .mtime = 0,
            .size = pax.items.len,
            .type_flag = 'x',
        });
        try output.appendSlice(allocator, pax.items);
        try wire.appendPadding(allocator, output, pax.items.len);
    }
    try wire.appendUstarHeader(allocator, output, .{
        .name = if (entry.name.len <= 100) entry.name else "PaxEntry",
        .link_name = if (entry.link_name.len <= 100) entry.link_name else "",
        .mode = effectiveMode(entry),
        .mtime = entry.mtime,
        .size = if (entry.kind == .file) entry.size else 0,
        .type_flag = typeFlag(entry.kind),
    });
}

fn effectiveMode(entry: EntryOptions) u32 {
    if (entry.mode != 0) return entry.mode;
    return switch (entry.kind) {
        .file => 0o644,
        .directory => 0o755,
        .symbolic_link, .hard_link => 0o777,
        .other => 0o644,
    };
}

fn typeFlag(kind: archive.Kind) u8 {
    return switch (kind) {
        .file => '0',
        .directory => '5',
        .symbolic_link => '2',
        .hard_link => '1',
        .other => unreachable,
    };
}

fn paddingFor(size: usize) usize {
    const remainder = size % wire.block_size;
    return if (remainder == 0) 0 else wire.block_size - remainder;
}

test {
    _ = @import("incremental_writer_tests.zig");
}
