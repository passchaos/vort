//! Incremental split/multi-disk ZIP writer.
//!
//! The adapter reuses the established incremental codec writer, but buffers
//! control records so local headers, descriptors, central entries, and archive
//! endings never cross a caller-visible part boundary.

const std = @import("std");
const core = @import("../core.zig");
const incremental = @import("incremental_writer.zig");
const wire = @import("wire.zig");

pub const Error = incremental.Error || error{
    InvalidZipArchive,
    InvalidZipSplitSize,
    ZipSplitLimitExceeded,
    InvalidZipWriterState,
    ZipWriterPoisoned,
};

pub const Options = struct {
    writer_options: incremental.Options = .{},
    max_part_size: usize = 64 * 1024 * 1024,
    max_parts: usize = std.math.maxInt(u16),
    /// Includes the four-byte split marker.
    max_archive_size: u64 = std.math.maxInt(u64),
};

pub const StepResult = struct {
    progress: core.Progress = .{},
    status: Status,

    pub const Status = enum {
        need_input,
        need_output,
        /// All bytes returned so far belong to the completed current part.
        /// Switch sinks before the next `step` call.
        part_done,
        done,
    };
};

pub const Phase = enum {
    marker_emit,
    ready,
    header_collect,
    header_emit,
    entry_data,
    descriptor_collect,
    descriptor_emit,
    central_fixed,
    central_variable,
    central_emit,
    ending_collect,
    ending_emit,
    done,
    poisoned,
};

const MarkerNext = enum {
    ready,
    header,
    central,
};

const Location = struct {
    disk: u16,
    offset: u64,
};

pub const Writer = struct {
    allocator: std.mem.Allocator,
    options: Options,
    inner: incremental.Writer,
    phase: Phase = .marker_emit,
    atomic: std.ArrayList(u8) = .empty,
    atomic_offset: usize = 0,
    atomic_target: usize = 4,
    locations: std.ArrayList(Location) = .empty,
    current_location_recorded: bool = false,
    central_index: usize = 0,
    central_size: usize = 0,
    central_start: ?u64 = null,
    central_disk: usize = 0,
    central_offset_on_disk: u64 = 0,
    central_entries_in_part: usize = 0,
    ending_patched: bool = false,
    virtual_offset: u64 = 0,
    part_index: usize = 0,
    part_base: u64 = 0,
    part_output: usize = 0,
    boundary_pending: bool = false,
    marker_next: MarkerNext = .ready,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        part_index: usize,
        part_output: usize,
        archive_output: u64,
        entry_count: usize,
        central_size: usize,
        pending_atomic: usize,
        boundary_pending: bool,
        inner: incremental.Writer.Snapshot,
    };

    pub fn init(
        allocator: std.mem.Allocator,
    ) (Error || std.mem.Allocator.Error)!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        options: Options,
    ) (Error || std.mem.Allocator.Error)!Self {
        if (options.max_part_size < 4) return error.InvalidZipSplitSize;
        if (options.max_parts == 0 or options.max_parts > std.math.maxInt(u16))
            return error.ZipSplitLimitExceeded;
        if (options.max_archive_size < 4) return error.OutputLimitExceeded;
        var writer_options = options.writer_options;
        writer_options.initial_offset = 4;
        writer_options.stop_at_record_boundaries = true;
        writer_options.max_archive_size = @min(
            writer_options.max_archive_size,
            options.max_archive_size - 4,
        );
        var inner = try incremental.Writer.initWithOptions(allocator, writer_options);
        errdefer inner.deinit();
        var atomic: std.ArrayList(u8) = .empty;
        errdefer atomic.deinit(allocator);
        try wire.appendU32(allocator, &atomic, wire.data_descriptor_signature);
        var locations: std.ArrayList(Location) = .empty;
        errdefer locations.deinit(allocator);
        return .{
            .allocator = allocator,
            .options = options,
            .inner = inner,
            .atomic = atomic,
            .locations = locations,
        };
    }

    pub fn deinit(self: *Self) void {
        self.inner.deinit();
        self.atomic.deinit(self.allocator);
        self.locations.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .part_index = self.part_index,
            .part_output = self.part_output,
            .archive_output = self.virtual_offset,
            .entry_count = self.locations.items.len,
            .central_size = self.central_size,
            .pending_atomic = self.atomic.items.len - self.atomic_offset,
            .boundary_pending = self.boundary_pending,
            .inner = self.inner.snapshot(),
        };
    }

    pub fn beginEntry(
        self: *Self,
        entry_options: incremental.EntryOptions,
    ) (Error || std.mem.Allocator.Error)!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready and self.phase != .marker_emit)
            return error.InvalidZipWriterState;
        if (self.phase == .ready and self.boundary_pending) try self.advancePart();
        try self.locations.ensureUnusedCapacity(self.allocator, 1);
        try self.inner.beginEntry(entry_options);
        self.current_location_recorded = false;
        if (self.phase == .marker_emit) {
            self.marker_next = .header;
            return;
        }
        self.clearAtomic();
        self.phase = .header_collect;
    }

    pub fn finishEntry(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .entry_data and
            self.phase != .header_collect and
            self.phase != .header_emit and
            !(self.phase == .marker_emit and self.marker_next == .header))
            return error.InvalidZipWriterState;
        return self.inner.finishEntry();
    }

    pub fn finishArchive(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        if (self.phase != .ready and self.phase != .marker_emit)
            return error.InvalidZipWriterState;
        if (self.phase == .ready and self.boundary_pending) try self.advancePart();
        try self.inner.finishArchive();
        self.central_index = 0;
        self.central_size = 0;
        self.central_start = null;
        self.central_entries_in_part = 0;
        if (self.phase == .marker_emit) {
            self.marker_next = .central;
        } else {
            self.clearAtomic();
            self.atomic_target = wire.central_file_header_len;
            self.phase = .central_fixed;
        }
    }

    pub fn step(
        self: *Self,
        input: []const u8,
        output: []u8,
    ) (Error || std.mem.Allocator.Error)!StepResult {
        if (self.phase == .poisoned) return error.ZipWriterPoisoned;
        return self.stepInner(input, output) catch |err| {
            self.phase = .poisoned;
            return err;
        };
    }

    fn stepInner(
        self: *Self,
        input: []const u8,
        output: []u8,
    ) (Error || std.mem.Allocator.Error)!StepResult {
        if (self.boundary_pending) try self.advancePart();
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .marker_emit => {
                if (!try self.prepareAtomicPart())
                    return self.partDone(input_read, output_written);
                try self.emitAtomic(output, &output_written);
                if (!self.atomicComplete())
                    return result(input_read, output_written, .need_output);
                self.clearAtomic();
                switch (self.marker_next) {
                    .ready => self.phase = .ready,
                    .header => self.phase = .header_collect,
                    .central => {
                        self.atomic_target = wire.central_file_header_len;
                        self.phase = .central_fixed;
                    },
                }
                self.marker_next = .ready;
                if (self.part_output == self.options.max_part_size)
                    return self.partDone(input_read, output_written);
                if (output_written == output.len)
                    return result(
                        input_read,
                        output_written,
                        if (self.phase == .ready and input_read == input.len)
                            .need_input
                        else
                            .need_output,
                    );
            },
            .ready => {
                if (input_read != input.len) return error.InvalidZipWriterState;
                return result(input_read, output_written, .need_input);
            },
            .header_collect => {
                try self.collectUntil(.entry_data);
                self.phase = .header_emit;
            },
            .header_emit => {
                if (!try self.prepareAtomicPart())
                    return self.partDone(input_read, output_written);
                if (!self.current_location_recorded) {
                    if (self.part_index >= std.math.maxInt(u16))
                        return error.ZipSplitLimitExceeded;
                    self.locations.appendAssumeCapacity(.{
                        .disk = @intCast(self.part_index),
                        .offset = self.virtual_offset - self.part_base,
                    });
                    self.current_location_recorded = true;
                }
                try self.emitAtomic(output, &output_written);
                if (!self.atomicComplete())
                    return result(input_read, output_written, .need_output);
                self.clearAtomic();
                self.phase = .entry_data;
                if (self.part_output == self.options.max_part_size)
                    return self.partDone(input_read, output_written);
                if (output_written == output.len)
                    return result(
                        input_read,
                        output_written,
                        if (!self.inner.snapshot().finish_entry_requested and
                            input_read == input.len)
                            .need_input
                        else
                            .need_output,
                    );
            },
            .entry_data => {
                const part_remaining = self.options.max_part_size - self.part_output;
                if (part_remaining == 0)
                    return self.partDone(input_read, output_written);
                const output_remaining = output.len - output_written;
                if (output_remaining == 0)
                    return result(input_read, output_written, .need_output);
                const capacity = @min(part_remaining, output_remaining);
                const inner_result = try self.inner.step(
                    input[input_read..],
                    output[output_written..][0..capacity],
                );
                input_read += inner_result.progress.input_read;
                try self.accountOutput(inner_result.progress.output_written);
                output_written += inner_result.progress.output_written;
                if (self.inner.snapshot().phase == .entry_descriptor) {
                    self.clearAtomic();
                    self.phase = .descriptor_collect;
                }
                if (self.part_output == self.options.max_part_size)
                    return self.partDone(input_read, output_written);
                if (self.phase == .descriptor_collect) continue;
                return result(
                    input_read,
                    output_written,
                    switch (inner_result.status) {
                        .need_input => .need_input,
                        .need_output => .need_output,
                        .done => return error.InvalidZipArchive,
                    },
                );
            },
            .descriptor_collect => {
                try self.collectUntil(.ready);
                self.phase = .descriptor_emit;
            },
            .descriptor_emit => {
                if (!try self.prepareAtomicPart())
                    return self.partDone(input_read, output_written);
                try self.emitAtomic(output, &output_written);
                if (!self.atomicComplete())
                    return result(input_read, output_written, .need_output);
                self.clearAtomic();
                self.phase = .ready;
                if (self.part_output == self.options.max_part_size)
                    return self.partDone(input_read, output_written);
                if (output_written == output.len)
                    return result(input_read, output_written, .need_input);
            },
            .central_fixed => {
                if (self.central_index == self.locations.items.len and
                    self.inner.snapshot().phase == .archive_end)
                {
                    self.clearAtomic();
                    self.phase = .ending_collect;
                    continue;
                }
                const available = try self.collectCentralTarget();
                if (!available) {
                    if (self.central_index != self.locations.items.len)
                        return error.InvalidZipArchive;
                    self.clearAtomic();
                    self.phase = .ending_collect;
                    continue;
                }
                const fixed: *const [wire.central_file_header_len]u8 =
                    self.atomic.items[0..wire.central_file_header_len];
                const name_len: usize = std.mem.readInt(u16, fixed[28..30], .little);
                const extra_len: usize = std.mem.readInt(u16, fixed[30..32], .little);
                const comment_len: usize = std.mem.readInt(u16, fixed[32..34], .little);
                self.atomic_target = try checkedAdd(
                    wire.central_file_header_len,
                    try checkedAdd(name_len, try checkedAdd(extra_len, comment_len)),
                );
                if (self.atomic_target > self.options.max_part_size)
                    return error.InvalidZipSplitSize;
                self.phase = .central_variable;
            },
            .central_variable => {
                if (!try self.collectCentralTarget()) return error.InvalidZipArchive;
                if (self.central_index >= self.locations.items.len)
                    return error.InvalidZipArchive;
                try patchCentral(self.atomic.items, self.locations.items[self.central_index]);
                self.phase = .central_emit;
            },
            .central_emit => {
                if (!try self.prepareAtomicPart())
                    return self.partDone(input_read, output_written);
                if (self.central_start == null) {
                    self.central_start = self.virtual_offset;
                    self.central_disk = self.part_index;
                    self.central_offset_on_disk = self.virtual_offset - self.part_base;
                }
                try self.emitAtomic(output, &output_written);
                if (!self.atomicComplete())
                    return result(input_read, output_written, .need_output);
                self.central_size = try checkedAdd(self.central_size, self.atomic.items.len);
                self.central_entries_in_part += 1;
                self.central_index += 1;
                self.clearAtomic();
                self.atomic_target = wire.central_file_header_len;
                self.phase = .central_fixed;
                if (self.part_output == self.options.max_part_size)
                    return self.partDone(input_read, output_written);
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
            },
            .ending_collect => {
                try self.collectUntil(.done);
                self.ending_patched = false;
                self.phase = .ending_emit;
            },
            .ending_emit => {
                if (!try self.prepareAtomicPart())
                    return self.partDone(input_read, output_written);
                if (self.central_start == null) {
                    self.central_start = self.virtual_offset;
                    self.central_disk = self.part_index;
                    self.central_offset_on_disk = self.virtual_offset - self.part_base;
                }
                if (!self.ending_patched) {
                    try patchEnding(
                        self.atomic.items,
                        self.part_index,
                        self.virtual_offset - self.part_base,
                        self.central_disk,
                        self.central_offset_on_disk,
                        self.central_entries_in_part,
                        self.locations.items.len,
                        self.part_index + 1,
                    );
                    self.ending_patched = true;
                }
                try self.emitAtomic(output, &output_written);
                if (!self.atomicComplete())
                    return result(input_read, output_written, .need_output);
                self.clearAtomic();
                self.phase = .done;
                return result(input_read, output_written, .done);
            },
            .done => {
                if (input_read != input.len) return error.TrailingData;
                return result(input_read, output_written, .done);
            },
            .poisoned => return error.ZipWriterPoisoned,
        };
    }

    fn collectUntil(
        self: *Self,
        wanted_phase: incremental.Phase,
    ) (Error || std.mem.Allocator.Error)!void {
        var scratch: [4096]u8 = undefined;
        while (self.inner.snapshot().phase != wanted_phase) {
            const before = self.inner.snapshot().phase;
            const inner_result = try self.inner.step("", &scratch);
            if (inner_result.progress.input_read != 0)
                return error.InvalidZipArchive;
            try self.atomic.appendSlice(
                self.allocator,
                scratch[0..inner_result.progress.output_written],
            );
            if (self.atomic.items.len > self.options.max_part_size)
                return error.InvalidZipSplitSize;
            if (inner_result.progress.output_written == 0 and
                self.inner.snapshot().phase == before)
                return error.InvalidZipArchive;
        }
    }

    /// Collect exactly `atomic_target` central bytes without consuming the
    /// first byte of the next central record or archive ending.
    fn collectCentralTarget(
        self: *Self,
    ) (Error || std.mem.Allocator.Error)!bool {
        var scratch: [4096]u8 = undefined;
        while (self.atomic.items.len < self.atomic_target) {
            const missing = self.atomic_target - self.atomic.items.len;
            const inner_result = try self.inner.step(
                "",
                scratch[0..@min(scratch.len, missing)],
            );
            if (inner_result.progress.input_read != 0)
                return error.InvalidZipArchive;
            if (inner_result.progress.output_written != 0) {
                try self.atomic.appendSlice(
                    self.allocator,
                    scratch[0..inner_result.progress.output_written],
                );
                continue;
            }
            if (self.inner.snapshot().phase == .archive_end and
                self.atomic.items.len == 0)
                return false;
            return error.InvalidZipArchive;
        }
        return true;
    }

    fn prepareAtomicPart(self: *Self) Error!bool {
        if (self.atomic.items.len > self.options.max_part_size)
            return error.InvalidZipSplitSize;
        if (self.atomic_offset != 0) return true;
        const remaining = self.options.max_part_size - self.part_output;
        if (self.atomic.items.len <= remaining) return true;
        if (self.part_output == 0) return error.InvalidZipSplitSize;
        try self.requestPartBoundary();
        return false;
    }

    fn emitAtomic(self: *Self, output: []u8, output_written: *usize) Error!void {
        const remaining = self.atomic.items[self.atomic_offset..];
        const part_remaining = self.options.max_part_size - self.part_output;
        const take = @min(remaining.len, @min(part_remaining, output.len - output_written.*));
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.atomic_offset += take;
        output_written.* += take;
        try self.accountOutput(take);
    }

    fn atomicComplete(self: *const Self) bool {
        return self.atomic_offset == self.atomic.items.len;
    }

    fn clearAtomic(self: *Self) void {
        self.atomic.clearRetainingCapacity();
        self.atomic_offset = 0;
        self.atomic_target = 0;
    }

    fn accountOutput(self: *Self, amount: usize) Error!void {
        self.virtual_offset = std.math.add(
            u64,
            self.virtual_offset,
            @as(u64, @intCast(amount)),
        ) catch return error.IntegerOverflow;
        self.part_output = try checkedAdd(self.part_output, amount);
        if (self.virtual_offset > self.options.max_archive_size)
            return error.OutputLimitExceeded;
    }

    fn requestPartBoundary(self: *Self) Error!void {
        if (self.part_index + 1 >= self.options.max_parts)
            return error.ZipSplitLimitExceeded;
        self.boundary_pending = true;
    }

    fn advancePart(self: *Self) Error!void {
        if (!self.boundary_pending or self.part_output == 0)
            return error.InvalidZipWriterState;
        self.part_index += 1;
        if (self.part_index >= std.math.maxInt(u16))
            return error.ZipSplitLimitExceeded;
        self.part_base = self.virtual_offset;
        self.part_output = 0;
        self.central_entries_in_part = 0;
        self.boundary_pending = false;
    }

    fn partDone(self: *Self, input_read: usize, output_written: usize) Error!StepResult {
        if (!self.boundary_pending) try self.requestPartBoundary();
        return result(input_read, output_written, .part_done);
    }
};

fn patchCentral(record: []u8, location: Location) Error!void {
    if (record.len < wire.central_file_header_len or
        std.mem.readInt(u32, record[0..4], .little) != wire.central_file_signature)
        return error.InvalidZipArchive;
    std.mem.writeInt(u16, record[34..36], location.disk, .little);
    const legacy_offset = std.mem.readInt(u32, record[42..46], .little);
    if (legacy_offset != std.math.maxInt(u32)) {
        if (location.offset >= std.math.maxInt(u32))
            return error.ZipSplitLimitExceeded;
        std.mem.writeInt(u32, record[42..46], @intCast(location.offset), .little);
        return;
    }
    const name_len: usize = std.mem.readInt(u16, record[28..30], .little);
    const extra_len: usize = std.mem.readInt(u16, record[30..32], .little);
    const extra_offset = wire.central_file_header_len + name_len;
    const extra_end = try checkedEnd(extra_offset, extra_len, record.len);
    var cursor = extra_offset;
    var zip64_payload: ?struct { offset: usize, len: usize } = null;
    while (cursor < extra_end) {
        const payload_offset = try checkedEnd(cursor, 4, extra_end);
        const field_id = std.mem.readInt(u16, record[cursor..][0..2], .little);
        const field_len: usize = std.mem.readInt(u16, record[cursor + 2 ..][0..2], .little);
        const next = try checkedEnd(payload_offset, field_len, extra_end);
        if (field_id == wire.zip64_extra_id) {
            if (zip64_payload != null) return error.InvalidZipArchive;
            zip64_payload = .{ .offset = payload_offset, .len = field_len };
        }
        cursor = next;
    }
    const zip64 = zip64_payload orelse return error.InvalidZipArchive;
    var payload_cursor: usize = 0;
    if (std.mem.readInt(u32, record[24..28], .little) == std.math.maxInt(u32))
        payload_cursor = try checkedEnd(payload_cursor, 8, zip64.len);
    if (std.mem.readInt(u32, record[20..24], .little) == std.math.maxInt(u32))
        payload_cursor = try checkedEnd(payload_cursor, 8, zip64.len);
    _ = try checkedEnd(payload_cursor, 8, zip64.len);
    const position = try checkedAdd(zip64.offset, payload_cursor);
    std.mem.writeInt(u64, record[position..][0..8], location.offset, .little);
}

fn patchEnding(
    ending: []u8,
    end_disk: usize,
    ending_offset_on_disk: u64,
    central_disk: usize,
    central_offset: u64,
    entries_on_disk: usize,
    entry_count: usize,
    part_count: usize,
) Error!void {
    if (end_disk >= std.math.maxInt(u16) or central_disk >= std.math.maxInt(u16) or
        part_count > std.math.maxInt(u16))
        return error.ZipSplitLimitExceeded;
    if (ending.len < wire.end_of_central_len) return error.InvalidZipArchive;
    const signature = std.mem.readInt(u32, ending[0..4], .little);
    if (signature == wire.zip64_end_of_central_signature) {
        const payload_len = std.math.cast(usize, std.mem.readInt(u64, ending[4..12], .little)) orelse
            return error.ZipSplitLimitExceeded;
        const locator_offset = try checkedAdd(12, payload_len);
        const end_offset = try checkedAdd(locator_offset, wire.zip64_end_of_central_locator_len);
        _ = try checkedEnd(end_offset, wire.end_of_central_len, ending.len);
        if (std.mem.readInt(u32, ending[locator_offset..][0..4], .little) !=
            wire.zip64_end_of_central_locator_signature or
            std.mem.readInt(u32, ending[end_offset..][0..4], .little) !=
                wire.end_of_central_signature)
            return error.InvalidZipArchive;
        std.mem.writeInt(u32, ending[16..20], @intCast(end_disk), .little);
        std.mem.writeInt(u32, ending[20..24], @intCast(central_disk), .little);
        std.mem.writeInt(u64, ending[24..32], entries_on_disk, .little);
        std.mem.writeInt(u64, ending[32..40], entry_count, .little);
        std.mem.writeInt(u64, ending[48..56], central_offset, .little);
        std.mem.writeInt(u32, ending[locator_offset + 4 ..][0..4], @intCast(end_disk), .little);
        std.mem.writeInt(
            u64,
            ending[locator_offset + 8 ..][0..8],
            ending_offset_on_disk,
            .little,
        );
        std.mem.writeInt(u32, ending[locator_offset + 16 ..][0..4], @intCast(part_count), .little);
        std.mem.writeInt(u16, ending[end_offset + 4 ..][0..2], @intCast(end_disk), .little);
        std.mem.writeInt(u16, ending[end_offset + 6 ..][0..2], @intCast(central_disk), .little);
        if (std.mem.readInt(u16, ending[end_offset + 8 ..][0..2], .little) !=
            std.math.maxInt(u16))
            std.mem.writeInt(u16, ending[end_offset + 8 ..][0..2], @intCast(entries_on_disk), .little);
        if (std.mem.readInt(u32, ending[end_offset + 16 ..][0..4], .little) !=
            std.math.maxInt(u32))
            std.mem.writeInt(u32, ending[end_offset + 16 ..][0..4], @intCast(central_offset), .little);
        return;
    }
    if (signature != wire.end_of_central_signature or
        entries_on_disk >= std.math.maxInt(u16) or
        entry_count >= std.math.maxInt(u16) or
        central_offset >= std.math.maxInt(u32))
        return error.InvalidZipArchive;
    std.mem.writeInt(u16, ending[4..6], @intCast(end_disk), .little);
    std.mem.writeInt(u16, ending[6..8], @intCast(central_disk), .little);
    std.mem.writeInt(u16, ending[8..10], @intCast(entries_on_disk), .little);
    std.mem.writeInt(u16, ending[10..12], @intCast(entry_count), .little);
    std.mem.writeInt(u32, ending[16..20], @intCast(central_offset), .little);
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

fn result(input_read: usize, output_written: usize, status: StepResult.Status) StepResult {
    return .{
        .progress = .{
            .input_read = input_read,
            .output_written = output_written,
        },
        .status = status,
    };
}
