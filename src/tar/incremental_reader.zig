//! Bounded caller-output TAR reader.

const std = @import("std");
const archive = @import("archive.zig");
const sparse = @import("sparse.zig");
const OwnedAttributes = @import("incremental_reader/metadata.zig").OwnedAttributes;

pub const Error = archive.Error || sparse.Error || std.mem.Allocator.Error || error{
    InvalidTarReaderState,
    TarReaderPoisoned,
};

pub const Options = struct {
    max_entries: usize = std.math.maxInt(usize),
    max_control_record_size: usize = 16 * 1024 * 1024,
    max_metadata_size: usize = 64 * 1024 * 1024,
    max_logical_entry_size: usize = std.math.maxInt(usize),
    max_total_output_size: usize = std.math.maxInt(usize),
    max_sparse_extents: usize = 1024 * 1024,
    max_archive_size: u64 = std.math.maxInt(u64),
};

pub const Phase = enum {
    header,
    control_data,
    control_padding,
    old_gnu_extensions,
    pax_1_0_map,
    pax_1_0_padding,
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
    entry_header,
    entry_done,
    done,
};

pub const StepResult = struct {
    input_read: usize = 0,
    output_written: usize = 0,
    status: Status,
};

/// `name` and `link_name` borrow reader-owned memory. They remain valid through
/// member output and are released when the corresponding `.entry_done` occurs.
pub const EntryInfo = struct {
    name: []const u8,
    link_name: []const u8,
    kind: archive.Kind,
    type_flag: u8,
    mode: u32,
    mtime: u64,
    size: usize,
    stored_size: usize,
    header_offset: u64,
    data_offset: u64,
    sparse_format: ?sparse.Format = null,
    sparse_extent_count: usize = 0,
};

const CurrentEntry = struct {
    info: EntryInfo,
    physical_size: usize,
    physical_read: usize = 0,
    logical_written: usize = 0,
    padding_remaining: usize,
    sparse_iterator: ?sparse.Iterator = null,
    sparse_extent: ?sparse.Extent = null,
};

pub const Reader = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header: [sparse.block_size]u8 = undefined,
    header_len: usize = 0,
    header_offset: u64 = 0,
    extension: [sparse.block_size]u8 = undefined,
    extension_len: usize = 0,
    control: std.ArrayList(u8) = .empty,
    control_type: u8 = 0,
    control_expected: usize = 0,
    control_padding_remaining: usize = 0,
    sparse_map: std.ArrayList(u8) = .empty,
    pax_1_0_expected_lines: ?usize = null,
    pax_1_0_lines: usize = 0,
    pax_1_0_padding_remaining: usize = 0,
    pending_sparse_plan: ?sparse.Plan = null,
    global: OwnedAttributes = .{},
    pending: OwnedAttributes = .{},
    entry_name: [256]u8 = undefined,
    entry_name_len: usize = 0,
    entry_link_name: [100]u8 = undefined,
    entry_link_name_len: usize = 0,
    current: ?CurrentEntry = null,
    entry_count: usize = 0,
    total_input: u64 = 0,
    total_output: usize = 0,
    input_finished: bool = false,

    const Self = @This();

    pub const Snapshot = struct {
        phase: Phase,
        input_read: u64,
        output_written: usize,
        entry_count: usize,
        header_received: usize,
        control_received: usize,
        control_expected: usize,
        current_logical_written: usize,
        current_logical_size: usize,
        current_physical_read: usize,
        current_physical_size: usize,
        retained_control_capacity: usize,
        retained_sparse_map_capacity: usize,
        input_finished: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Self) void {
        self.global.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.control.deinit(self.allocator);
        self.sparse_map.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .entry_count = self.entry_count,
            .header_received = self.header_len,
            .control_received = self.control.items.len,
            .control_expected = self.control_expected,
            .current_logical_written = if (self.current) |entry| entry.logical_written else 0,
            .current_logical_size = if (self.current) |entry| entry.info.size else 0,
            .current_physical_read = if (self.current) |entry| entry.physical_read else 0,
            .current_physical_size = if (self.current) |entry| entry.physical_size else 0,
            .retained_control_capacity = self.control.capacity,
            .retained_sparse_map_capacity = self.sparse_map.capacity,
            .input_finished = self.input_finished,
        };
    }

    pub fn currentEntry(self: *const Self) ?EntryInfo {
        return if (self.current) |current| current.info else null;
    }

    /// Marks the caller's input stream as complete. A clean entry boundary,
    /// one all-zero end block, or the standard two-block terminator is valid.
    pub fn finish(self: *Self) Error!void {
        if (self.phase == .poisoned) return error.TarReaderPoisoned;
        if (self.phase == .done) {
            self.input_finished = true;
            return;
        }
        const valid = switch (self.phase) {
            .header => self.header_len == 0 and !archive.hasPending(self.pending.view()),
            .archive_end => archive.allZero(self.header[0..self.header_len]),
            else => false,
        };
        if (!valid) {
            self.phase = .poisoned;
            return error.TruncatedFrame;
        }
        self.input_finished = true;
        self.phase = .done;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!StepResult {
        if (self.phase == .poisoned) return error.TarReaderPoisoned;
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
                if (!try self.fillFixed(input, &input_read, &self.header, &self.header_len))
                    return result(input_read, output_written, .need_input);
                self.header_offset = self.total_input - sparse.block_size;
                if (archive.allZero(&self.header)) {
                    self.header_len = 0;
                    self.phase = .archive_end;
                    continue;
                }
                try archive.validateChecksum(&self.header);
                try self.startHeader();
            },
            .control_data => {
                const remaining = self.control_expected - self.control.items.len;
                const take = @min(remaining, input.len - input_read);
                try self.recordInput(take);
                try self.control.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                if (self.control.items.len != self.control_expected)
                    return result(input_read, output_written, .need_input);
                try self.applyControl();
                self.control_padding_remaining = paddingFor(self.control_expected);
                self.phase = .control_padding;
            },
            .control_padding => {
                const take = @min(self.control_padding_remaining, input.len - input_read);
                try self.recordInput(take);
                input_read += take;
                self.control_padding_remaining -= take;
                if (self.control_padding_remaining != 0)
                    return result(input_read, output_written, .need_input);
                self.control.clearRetainingCapacity();
                self.header_len = 0;
                self.phase = .header;
            },
            .old_gnu_extensions => {
                if (!try self.fillFixed(input, &input_read, &self.extension, &self.extension_len))
                    return result(input_read, output_written, .need_input);
                if (self.sparse_map.items.len > self.options.max_control_record_size -| sparse.block_size)
                    return error.OutputLimitExceeded;
                try self.sparse_map.appendSlice(self.allocator, &self.extension);
                const extended = self.extension[504];
                if (extended > 1) return error.InvalidTarHeader;
                self.extension_len = 0;
                if (extended == 0) {
                    try self.prepareOldGnuEntry();
                }
            },
            .pax_1_0_map => {
                while (input_read < input.len) {
                    if (self.sparse_map.items.len == self.options.max_control_record_size)
                        return error.OutputLimitExceeded;
                    const byte = input[input_read];
                    try self.recordInput(1);
                    try self.sparse_map.append(self.allocator, byte);
                    input_read += 1;
                    if (byte != '\n') continue;
                    self.pax_1_0_lines = std.math.add(usize, self.pax_1_0_lines, 1) catch
                        return error.IntegerOverflow;
                    if (self.pax_1_0_expected_lines == null) {
                        const count = std.fmt.parseInt(
                            usize,
                            self.sparse_map.items[0 .. self.sparse_map.items.len - 1],
                            10,
                        ) catch return error.InvalidTarHeader;
                        if (count > self.options.max_sparse_extents)
                            return error.OutputLimitExceeded;
                        const pair_lines = std.math.mul(usize, count, 2) catch
                            return error.IntegerOverflow;
                        self.pax_1_0_expected_lines = std.math.add(usize, pair_lines, 1) catch
                            return error.IntegerOverflow;
                    }
                    if (self.pax_1_0_lines == self.pax_1_0_expected_lines.?) {
                        try self.finishPax10Map();
                        break;
                    }
                }
                if (self.phase == .pax_1_0_map)
                    return result(input_read, output_written, .need_input);
            },
            .pax_1_0_padding => {
                const take = @min(self.pax_1_0_padding_remaining, input.len - input_read);
                for (input[input_read..][0..take]) |byte|
                    if (byte != 0) return error.InvalidTarHeader;
                try self.recordInput(take);
                input_read += take;
                self.pax_1_0_padding_remaining -= take;
                if (self.pax_1_0_padding_remaining != 0)
                    return result(input_read, output_written, .need_input);
                const plan = self.pending_sparse_plan orelse return error.InvalidTarReaderState;
                try self.prepareEntry(plan.logical_size, plan.physical_size, plan);
            },
            .entry_header => {
                self.phase = .entry_data;
                return result(input_read, output_written, .entry_header);
            },
            .entry_data => {
                if (self.current.?.sparse_iterator != null) {
                    try self.streamSparse(input, &input_read, output, &output_written);
                } else {
                    try self.streamRegular(input, &input_read, output, &output_written);
                }
                if (self.current.?.logical_written != self.current.?.info.size) {
                    const status: Status = if (output_written == output.len)
                        .need_output
                    else
                        .need_input;
                    return result(input_read, output_written, status);
                }
                if (self.current.?.physical_read != self.current.?.physical_size)
                    return error.InvalidTarHeader;
                self.phase = .entry_padding;
            },
            .entry_padding => {
                const entry = &self.current.?;
                const take = @min(entry.padding_remaining, input.len - input_read);
                try self.recordInput(take);
                input_read += take;
                entry.padding_remaining -= take;
                if (entry.padding_remaining != 0)
                    return result(input_read, output_written, .need_input);
                self.current = null;
                self.pending.deinit(self.allocator);
                self.entry_count = std.math.add(usize, self.entry_count, 1) catch
                    return error.IntegerOverflow;
                self.header_len = 0;
                self.phase = .header;
                return result(input_read, output_written, .entry_done);
            },
            .archive_end => {
                if (!try self.fillFixed(input, &input_read, &self.header, &self.header_len))
                    return result(input_read, output_written, .need_input);
                if (!archive.allZero(&self.header)) return error.InvalidTarArchive;
                self.phase = .done;
                self.input_finished = true;
                return result(input_read, output_written, .done);
            },
            .done, .poisoned => unreachable,
        };
    }

    fn startHeader(self: *Self) Error!void {
        const stored_size = try archive.u64ToUsize(try archive.parseNumber(self.header[124..136]));
        const type_flag = self.header[156];
        switch (type_flag) {
            'x', 'g', 'L', 'K' => {
                if (stored_size > self.options.max_control_record_size)
                    return error.OutputLimitExceeded;
                self.control.clearRetainingCapacity();
                try self.control.ensureTotalCapacityPrecise(self.allocator, stored_size);
                self.control_type = type_flag;
                self.control_expected = stored_size;
                self.phase = .control_data;
            },
            'S' => {
                if (archive.hasSparse(self.pending.view())) return error.InvalidTarHeader;
                const extended = self.header[482];
                if (extended > 1) return error.InvalidTarHeader;
                self.sparse_map.clearRetainingCapacity();
                if (126 > self.options.max_control_record_size)
                    return error.OutputLimitExceeded;
                try self.sparse_map.appendSlice(self.allocator, self.header[386..512]);
                if (extended == 0) {
                    try self.prepareOldGnuEntry();
                } else {
                    self.extension_len = 0;
                    self.phase = .old_gnu_extensions;
                }
            },
            else => try self.prepareOrdinaryOrPaxEntry(stored_size),
        }
    }

    fn applyControl(self: *Self) Error!void {
        const global_size = try self.global.byteLen();
        const pending_size = try self.pending.byteLen();
        switch (self.control_type) {
            'x', 'g' => {
                var parsed: archive.Attributes = .{};
                try archive.parsePax(self.control.items, &parsed);
                if (self.control_type == 'x') {
                    try self.pending.apply(
                        self.allocator,
                        parsed,
                        global_size,
                        self.options.max_metadata_size,
                    );
                } else {
                    try self.global.apply(
                        self.allocator,
                        parsed,
                        pending_size,
                        self.options.max_metadata_size,
                    );
                    if (archive.hasSparse(self.global.view())) return error.InvalidTarHeader;
                }
            },
            'L' => try self.pending.setPath(
                self.allocator,
                archive.trimExtensionString(self.control.items),
                global_size,
                self.options.max_metadata_size,
            ),
            'K' => try self.pending.setLinkPath(
                self.allocator,
                archive.trimExtensionString(self.control.items),
                global_size,
                self.options.max_metadata_size,
            ),
            else => unreachable,
        }
    }

    fn prepareOldGnuEntry(self: *Self) Error!void {
        const logical_size = try archive.u64ToUsize(try archive.parseNumber(self.header[483..495]));
        const stored_size = try archive.u64ToUsize(try archive.parseNumber(self.header[124..136]));
        const plan = try sparse.inspectOldGnu(self.sparse_map.items, logical_size);
        try self.validateSparsePlan(plan);
        if (plan.physical_size != stored_size) return error.InvalidTarHeader;
        try self.prepareEntry(logical_size, stored_size, plan);
    }

    fn prepareOrdinaryOrPaxEntry(self: *Self, header_size: usize) Error!void {
        const attributes = self.pending.view();
        if (!archive.hasSparse(attributes)) {
            const actual_size = try archive.u64ToUsize(
                attributes.size orelse self.global.size orelse header_size,
            );
            try self.prepareEntry(actual_size, actual_size, null);
            return;
        }
        if (attributes.size != null) return error.InvalidTarHeader;
        const logical_size = try archive.u64ToUsize(attributes.sparse_size orelse
            return error.InvalidTarHeader);
        if (attributes.sparse_major) |major| {
            if (major != 1 or attributes.sparse_minor != 0 or
                attributes.sparse_name == null or attributes.sparse_map != null or
                attributes.sparse_numblocks != null or attributes.sparse_pax_00 != null)
                return error.UnsupportedTarEntryType;
            try self.checkEntryLimits(logical_size);
            self.sparse_map.clearRetainingCapacity();
            self.pax_1_0_expected_lines = null;
            self.pax_1_0_lines = 0;
            self.pending_sparse_plan = null;
            self.control_expected = header_size;
            self.phase = .pax_1_0_map;
            return;
        }
        if (attributes.sparse_minor != null) return error.InvalidTarHeader;
        const declared_count = if (attributes.sparse_numblocks) |count|
            try archive.u64ToUsize(count)
        else
            null;
        if (declared_count) |count|
            if (count > self.options.max_sparse_extents) return error.OutputLimitExceeded;

        const plan = if (attributes.sparse_pax_00) |pax_payload| pax00: {
            if (attributes.sparse_map != null) return error.InvalidTarHeader;
            break :pax00 try sparse.inspectPax00(
                pax_payload,
                declared_count,
                logical_size,
            );
        } else pax01: {
            const map = attributes.sparse_map orelse return error.InvalidTarHeader;
            break :pax01 try sparse.inspectPax01(
                map,
                declared_count,
                logical_size,
            );
        };
        try self.validateSparsePlan(plan);
        if (plan.physical_size != header_size) return error.InvalidTarHeader;
        try self.prepareEntry(logical_size, header_size, plan);
    }

    fn finishPax10Map(self: *Self) Error!void {
        const attributes = self.pending.view();
        const logical_size = try archive.u64ToUsize(attributes.sparse_size orelse
            return error.InvalidTarHeader);
        const plan = try sparse.inspectPax10(self.sparse_map.items, logical_size);
        try self.validateSparsePlan(plan);
        const padded_map_size = try paddedSize(self.sparse_map.items.len);
        if (padded_map_size > self.control_expected) return error.InvalidTarHeader;
        if (plan.physical_size != self.control_expected - padded_map_size)
            return error.InvalidTarHeader;
        self.pending_sparse_plan = plan;
        self.pax_1_0_padding_remaining = padded_map_size - self.sparse_map.items.len;
        self.phase = .pax_1_0_padding;
    }

    fn prepareEntry(
        self: *Self,
        logical_size: usize,
        stored_size: usize,
        sparse_plan: ?sparse.Plan,
    ) Error!void {
        try self.checkEntryLimits(logical_size);
        const type_flag = self.header[156];
        const kind = archive.kindFromType(type_flag);
        if (sparse_plan != null and kind != .file) return error.InvalidTarHeader;
        const mode_u64 = try archive.parseNumber(self.header[100..108]);
        if (mode_u64 > std.math.maxInt(u32)) return error.InvalidTarHeader;

        self.entry_name_len = 0;
        self.entry_link_name_len = 0;
        const pending_view = self.pending.view();
        const name: []const u8 = if (pending_view.sparse_name orelse pending_view.path orelse self.global.path) |owned_name|
            owned_name
        else name: {
            const path = archive.pathFromHeader(&self.header);
            if (path.prefix.len != 0) {
                @memcpy(self.entry_name[0..path.prefix.len], path.prefix);
                self.entry_name_len = path.prefix.len;
                self.entry_name[self.entry_name_len] = '/';
                self.entry_name_len += 1;
            }
            @memcpy(self.entry_name[self.entry_name_len..][0..path.name.len], path.name);
            self.entry_name_len += path.name.len;
            break :name self.entry_name[0..self.entry_name_len];
        };
        const link_name: []const u8 = if (pending_view.link_path orelse self.global.link_path) |owned_link|
            owned_link
        else link: {
            const header_link = archive.headerString(self.header[157..257]);
            @memcpy(self.entry_link_name[0..header_link.len], header_link);
            self.entry_link_name_len = header_link.len;
            break :link self.entry_link_name[0..self.entry_link_name_len];
        };

        var iterator_value: ?sparse.Iterator = null;
        var first_extent: ?sparse.Extent = null;
        if (sparse_plan) |plan| {
            var iterator = plan.iterator();
            first_extent = try iterator.next();
            iterator_value = iterator;
        }
        const data_offset = self.total_input;
        const info = EntryInfo{
            .name = name,
            .link_name = link_name,
            .kind = kind,
            .type_flag = type_flag,
            .mode = @intCast(mode_u64),
            .mtime = try archive.parseNumber(self.header[136..148]),
            .size = logical_size,
            .stored_size = stored_size,
            .header_offset = self.header_offset,
            .data_offset = data_offset,
            .sparse_format = if (sparse_plan) |plan| plan.format else null,
            .sparse_extent_count = if (sparse_plan) |plan| plan.extent_count else 0,
        };
        self.current = .{
            .info = info,
            .physical_size = if (sparse_plan) |plan| plan.physical_size else logical_size,
            .padding_remaining = paddingFor(stored_size),
            .sparse_iterator = iterator_value,
            .sparse_extent = first_extent,
        };
        self.pending_sparse_plan = null;
        self.phase = .entry_header;
    }

    fn checkEntryLimits(self: *const Self, logical_size: usize) Error!void {
        if (self.entry_count == self.options.max_entries or
            logical_size > self.options.max_logical_entry_size)
            return error.OutputLimitExceeded;
        const total = std.math.add(usize, self.total_output, logical_size) catch
            return error.IntegerOverflow;
        if (total > self.options.max_total_output_size)
            return error.OutputLimitExceeded;
    }

    fn validateSparsePlan(self: *const Self, plan: sparse.Plan) Error!void {
        if (plan.extent_count > self.options.max_sparse_extents)
            return error.OutputLimitExceeded;
        if (plan.logical_size > self.options.max_logical_entry_size)
            return error.OutputLimitExceeded;
    }

    fn streamRegular(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        output: []u8,
        output_written: *usize,
    ) Error!void {
        const entry = &self.current.?;
        const remaining = entry.info.size - entry.logical_written;
        const take = @min(
            @min(remaining, input.len - input_read.*),
            output.len - output_written.*,
        );
        try self.recordInput(take);
        @memcpy(
            output[output_written.*..][0..take],
            input[input_read.*..][0..take],
        );
        input_read.* += take;
        output_written.* += take;
        entry.logical_written += take;
        entry.physical_read += take;
        try self.recordOutput(take);
    }

    fn streamSparse(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        output: []u8,
        output_written: *usize,
    ) Error!void {
        const entry = &self.current.?;
        while (entry.logical_written < entry.info.size) {
            while (entry.sparse_extent) |extent| {
                const extent_end = std.math.add(usize, extent.offset, extent.len) catch
                    return error.IntegerOverflow;
                if (entry.logical_written < extent_end) break;
                entry.sparse_extent = try entry.sparse_iterator.?.next();
            }
            const extent = entry.sparse_extent;
            const next_offset = if (extent) |value| value.offset else entry.info.size;
            if (entry.logical_written < next_offset) {
                const take = @min(
                    next_offset - entry.logical_written,
                    output.len - output_written.*,
                );
                @memset(output[output_written.*..][0..take], 0);
                output_written.* += take;
                entry.logical_written += take;
                try self.recordOutput(take);
                if (take == 0) return;
                continue;
            }
            const active = extent orelse return error.InvalidTarHeader;
            const extent_end = active.offset + active.len;
            const take = @min(
                @min(extent_end - entry.logical_written, input.len - input_read.*),
                output.len - output_written.*,
            );
            try self.recordInput(take);
            @memcpy(
                output[output_written.*..][0..take],
                input[input_read.*..][0..take],
            );
            input_read.* += take;
            output_written.* += take;
            entry.logical_written += take;
            entry.physical_read += take;
            try self.recordOutput(take);
            if (take == 0) return;
        }
    }

    fn fillFixed(
        self: *Self,
        input: []const u8,
        input_read: *usize,
        buffer: *[sparse.block_size]u8,
        received: *usize,
    ) Error!bool {
        const take = @min(sparse.block_size - received.*, input.len - input_read.*);
        try self.recordInput(take);
        @memcpy(buffer[received.*..][0..take], input[input_read.*..][0..take]);
        input_read.* += take;
        received.* += take;
        return received.* == sparse.block_size;
    }

    fn recordInput(self: *Self, count: usize) Error!void {
        const next = std.math.add(u64, self.total_input, count) catch
            return error.IntegerOverflow;
        if (next > self.options.max_archive_size) return error.OutputLimitExceeded;
        self.total_input = next;
    }

    fn recordOutput(self: *Self, count: usize) Error!void {
        self.total_output = std.math.add(usize, self.total_output, count) catch
            return error.IntegerOverflow;
        std.debug.assert(self.total_output <= self.options.max_total_output_size);
    }
};

fn paddingFor(size: usize) usize {
    const remainder = size % sparse.block_size;
    return if (remainder == 0) 0 else sparse.block_size - remainder;
}

fn paddedSize(size: usize) Error!usize {
    return std.math.add(usize, size, paddingFor(size)) catch error.IntegerOverflow;
}

fn result(input_read: usize, output_written: usize, status: Status) StepResult {
    return .{
        .input_read = input_read,
        .output_written = output_written,
        .status = status,
    };
}

test {
    _ = @import("incremental_reader_tests.zig");
}
