//! Sparse single-disk view over explicitly ordered split ZIP parts.
//!
//! The stream owns only copied slice descriptors, disk bases, and small
//! metadata patches. Archive payload bytes remain borrowed from the caller.

const std = @import("std");
const records = @import("../records.zig");
const wire = @import("../wire.zig");

pub const Error = records.Error || error{
    InvalidZipArchive,
    InvalidZipDiskOrder,
    OutputLimitExceeded,
    IntegerOverflow,
    RangeOutOfBounds,
    PartSourceReadFailed,
};

pub const PartSource = struct {
    context: *anyopaque,
    part_lengths: []const usize,
    read_at: *const fn (
        context: *anyopaque,
        disk: usize,
        offset: usize,
        output: []u8,
    ) error{PartSourceReadFailed}!usize,
};

pub const Options = struct {
    /// Maximum sum of all part lengths and logical normalized length.
    max_archive_size: usize = std.math.maxInt(usize),
    /// Maximum number of explicitly ordered parts accepted from the caller.
    max_parts: usize = std.math.maxInt(u32),
    /// Maximum number of central-directory entries parsed into the patch plan.
    max_entries: usize = std.math.maxInt(usize),
    /// Require the conventional `PK\x07\x08` marker at offset zero of disk 0.
    require_split_signature: bool = true,
};

const InitError = Error || std.mem.Allocator.Error;

const End = struct {
    offset: usize,
    disk: u16,
    central_disk: u16,
    entries_on_disk: u16,
    entry_count: u16,
    central_size: u32,
    central_offset: u32,
};

const Directory = struct {
    disk: usize,
    offset: usize,
    size: usize,
    entry_count: usize,
};

const CentralResult = struct {
    next: usize,
    local_offset: usize,
};

const Patch = struct {
    offset: usize,
    len: u8,
    bytes: [8]u8 = @splat(0),

    fn end(self: Patch) Error!usize {
        return checkedAdd(self.offset, self.len);
    }
};

const Backing = union(enum) {
    slices: []const []const u8,
    callback: PartSource,
};

const Source = struct {
    backing: Backing,
    bases: []const usize,
    total_len: usize,

    fn partCount(self: Source) usize {
        return switch (self.backing) {
            .slices => |parts| parts.len,
            .callback => |source| source.part_lengths.len,
        };
    }

    fn partLen(self: Source, disk: usize) usize {
        return switch (self.backing) {
            .slices => |parts| parts[disk].len,
            .callback => |source| source.part_lengths[disk],
        };
    }

    fn readPartExact(
        self: Source,
        disk: usize,
        offset: usize,
        output: []u8,
    ) Error!void {
        return switch (self.backing) {
            .slices => |parts| {
                @memcpy(output, parts[disk][offset..][0..output.len]);
            },
            .callback => |source| {
                var written: usize = 0;
                while (written < output.len) {
                    const amount = try source.read_at(
                        source.context,
                        disk,
                        offset + written,
                        output[written..],
                    );
                    if (amount == 0 or amount > output.len - written)
                        return error.InvalidZipArchive;
                    written += amount;
                }
            },
        };
    }

    fn copyExact(self: Source, offset: usize, output: []u8) Error!void {
        _ = try checkedEnd(offset, output.len, self.total_len);
        if (output.len == 0) return;
        var disk = self.diskForOffset(offset);
        var absolute = offset;
        var written: usize = 0;
        while (written < output.len) : (disk += 1) {
            if (disk >= self.partCount()) return error.InvalidZipArchive;
            const local = absolute - self.bases[disk];
            const take = @min(output.len - written, self.partLen(disk) - local);
            if (take == 0) return error.InvalidZipArchive;
            try self.readPartExact(disk, local, output[written..][0..take]);
            written += take;
            absolute += take;
        }
    }

    fn readInt(self: Source, comptime T: type, offset: usize) Error!T {
        var bytes: [@sizeOf(T)]u8 = undefined;
        try self.copyExact(offset, &bytes);
        return std.mem.readInt(T, &bytes, .little);
    }

    fn diskOffset(self: Source, disk: usize, offset: usize) Error!usize {
        if (disk >= self.partCount() or offset >= self.partLen(disk))
            return error.InvalidZipDiskOrder;
        return checkedAdd(self.bases[disk], offset);
    }

    fn diskForOffset(self: Source, offset: usize) usize {
        std.debug.assert(offset < self.total_len);
        var low: usize = 0;
        var high: usize = self.bases.len;
        while (low + 1 < high) {
            const middle = low + (high - low) / 2;
            if (self.bases[middle] <= offset)
                low = middle
            else
                high = middle;
        }
        return low;
    }
};

const Plan = struct {
    bases: []usize,
    patches: std.ArrayList(Patch),
    total_len: usize,
    first_record_offset: usize,

    fn deinit(self: *Plan, allocator: std.mem.Allocator) void {
        self.patches.deinit(allocator);
        allocator.free(self.bases);
        self.* = undefined;
    }
};

fn backingPartCount(backing: Backing) usize {
    return switch (backing) {
        .slices => |parts| parts.len,
        .callback => |source| source.part_lengths.len,
    };
}

fn backingPartLen(backing: Backing, disk: usize) usize {
    return switch (backing) {
        .slices => |parts| parts[disk].len,
        .callback => |source| source.part_lengths[disk],
    };
}

fn buildPlan(
    allocator: std.mem.Allocator,
    backing: Backing,
    options: Options,
) InitError!Plan {
    const part_count = backingPartCount(backing);
    if (part_count < 2 or part_count > std.math.maxInt(u32))
        return error.InvalidZipArchive;
    if (part_count > options.max_parts) return error.OutputLimitExceeded;
    const bases = try allocator.alloc(usize, part_count);
    errdefer allocator.free(bases);
    var total_len: usize = 0;
    for (bases, 0..) |*base, disk| {
        const part_len = backingPartLen(backing, disk);
        if (part_len == 0) return error.InvalidZipArchive;
        base.* = total_len;
        total_len = try checkedAdd(total_len, part_len);
        if (total_len > options.max_archive_size)
            return error.OutputLimitExceeded;
    }
    const source: Source = .{
        .backing = backing,
        .bases = bases,
        .total_len = total_len,
    };
    if (options.require_split_signature) {
        if (source.partLen(0) < 4 or
            try source.readInt(u32, 0) != wire.data_descriptor_signature)
            return error.InvalidZipDiskOrder;
    }
    const end = try parseEnd(allocator, source);
    var patches: std.ArrayList(Patch) = .empty;
    errdefer patches.deinit(allocator);
    const directory = if (hasZip64Sentinel(end))
        try normalizeZip64Plan(allocator, &patches, source, end)
    else
        try normalizeZip32Plan(allocator, &patches, source, end);
    if (directory.entry_count > options.max_entries)
        return error.OutputLimitExceeded;
    const central_offset = try source.diskOffset(directory.disk, directory.offset);
    const central_end = try checkedEnd(central_offset, directory.size, end.offset);
    var central_cursor = central_offset;
    var first_record_offset = central_offset;
    if (directory.size >= 4 and
        try source.readInt(u32, central_offset) == wire.archive_extra_data_signature)
    {
        _ = try checkedEnd(
            central_offset,
            wire.archive_extra_data_header_len,
            central_end,
        );
        const payload_len: usize = try source.readInt(u32, central_offset + 4);
        central_cursor = try checkedEnd(
            central_offset,
            try checkedAdd(wire.archive_extra_data_header_len, payload_len),
            central_end,
        );
    }
    for (0..directory.entry_count) |index| {
        const normalized = try normalizeCentralEntryPlan(
            allocator,
            &patches,
            source,
            central_cursor,
            central_end,
        );
        central_cursor = normalized.next;
        if (index == 0 or normalized.local_offset < first_record_offset)
            first_record_offset = normalized.local_offset;
    }
    if (central_cursor != central_end) return error.InvalidZipArchive;
    std.mem.sort(Patch, patches.items, {}, patchLessThan);
    var previous_end: usize = 0;
    for (patches.items, 0..) |metadata_patch, index| {
        const patch_end = try metadata_patch.end();
        if (patch_end > total_len or (index != 0 and metadata_patch.offset < previous_end))
            return error.InvalidZipArchive;
        previous_end = patch_end;
    }
    return .{
        .bases = bases,
        .patches = patches,
        .total_len = total_len,
        .first_record_offset = first_record_offset,
    };
}

/// Borrowed multi-slice ZIP bytes exposed as a logically normalized single-
/// disk byte stream. The caller-owned part payloads must outlive this value;
/// the outer slice descriptor array is copied during initialization.
pub const Stream = struct {
    allocator: std.mem.Allocator,
    parts: []const []const u8,
    bases: []usize,
    patches: std.ArrayList(Patch),
    total_len: usize,
    first_record_offset: usize,

    const Self = @This();

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        ordered_parts: []const []const u8,
        options: Options,
    ) InitError!Self {
        const parts = try allocator.alloc([]const u8, ordered_parts.len);
        errdefer allocator.free(parts);
        @memcpy(parts, ordered_parts);
        var plan = try buildPlan(allocator, .{ .slices = parts }, options);
        errdefer plan.deinit(allocator);
        return .{
            .allocator = allocator,
            .parts = parts,
            .bases = plan.bases,
            .patches = plan.patches,
            .total_len = plan.total_len,
            .first_record_offset = plan.first_record_offset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patches.deinit(self.allocator);
        self.allocator.free(self.bases);
        self.allocator.free(self.parts);
        self.* = undefined;
    }

    pub fn len(self: *const Self) usize {
        return self.total_len;
    }

    pub fn firstRecordOffset(self: *const Self) usize {
        return self.first_record_offset;
    }

    pub fn patchCount(self: *const Self) usize {
        return self.patches.items.len;
    }

    /// Reads normalized bytes at an absolute virtual archive offset.
    pub fn readAt(self: *const Self, offset: usize, output: []u8) Error!usize {
        if (offset > self.total_len) return error.RangeOutOfBounds;
        const written = @min(output.len, self.total_len - offset);
        if (written == 0) return 0;
        const source: Source = .{
            .backing = .{ .slices = self.parts },
            .bases = self.bases,
            .total_len = self.total_len,
        };
        try source.copyExact(offset, output[0..written]);
        const read_end = offset + written;
        const first_patch = firstPatchEndingAfter(self.patches.items, offset);
        for (self.patches.items[first_patch..]) |metadata_patch| {
            const patch_end = metadata_patch.offset + metadata_patch.len;
            if (metadata_patch.offset >= read_end) break;
            const overlap_start = @max(offset, metadata_patch.offset);
            const overlap_end = @min(read_end, patch_end);
            const source_start = overlap_start - metadata_patch.offset;
            const target_start = overlap_start - offset;
            const overlap_len = overlap_end - overlap_start;
            @memcpy(
                output[target_start..][0..overlap_len],
                metadata_patch.bytes[source_start..][0..overlap_len],
            );
        }
        return written;
    }
};

/// Sparse normalized stream backed by caller-defined on-demand part reads.
/// The callback context and the underlying parts must outlive this value; the
/// part-length descriptor array is copied during initialization.
pub const SourceStream = struct {
    allocator: std.mem.Allocator,
    source: PartSource,
    part_lengths: []usize,
    bases: []usize,
    patches: std.ArrayList(Patch),
    total_len: usize,
    first_record_offset: usize,

    const Self = @This();

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        source_value: PartSource,
        options: Options,
    ) InitError!Self {
        const part_lengths = try allocator.dupe(usize, source_value.part_lengths);
        errdefer allocator.free(part_lengths);
        var source = source_value;
        source.part_lengths = part_lengths;
        var plan = try buildPlan(allocator, .{ .callback = source }, options);
        errdefer plan.deinit(allocator);
        return .{
            .allocator = allocator,
            .source = source,
            .part_lengths = part_lengths,
            .bases = plan.bases,
            .patches = plan.patches,
            .total_len = plan.total_len,
            .first_record_offset = plan.first_record_offset,
        };
    }

    pub fn deinit(self: *Self) void {
        self.patches.deinit(self.allocator);
        self.allocator.free(self.bases);
        self.allocator.free(self.part_lengths);
        self.* = undefined;
    }

    pub fn len(self: *const Self) usize {
        return self.total_len;
    }

    pub fn firstRecordOffset(self: *const Self) usize {
        return self.first_record_offset;
    }

    pub fn patchCount(self: *const Self) usize {
        return self.patches.items.len;
    }

    pub fn readAt(self: *const Self, offset: usize, output: []u8) Error!usize {
        if (offset > self.total_len) return error.RangeOutOfBounds;
        const written = @min(output.len, self.total_len - offset);
        if (written == 0) return 0;
        const source: Source = .{
            .backing = .{ .callback = self.source },
            .bases = self.bases,
            .total_len = self.total_len,
        };
        try source.copyExact(offset, output[0..written]);
        const read_end = offset + written;
        const first_patch = firstPatchEndingAfter(self.patches.items, offset);
        for (self.patches.items[first_patch..]) |metadata_patch| {
            const patch_end = metadata_patch.offset + metadata_patch.len;
            if (metadata_patch.offset >= read_end) break;
            const overlap_start = @max(offset, metadata_patch.offset);
            const overlap_end = @min(read_end, patch_end);
            const source_start = overlap_start - metadata_patch.offset;
            const target_start = overlap_start - offset;
            const overlap_len = overlap_end - overlap_start;
            @memcpy(
                output[target_start..][0..overlap_len],
                metadata_patch.bytes[source_start..][0..overlap_len],
            );
        }
        return written;
    }
};

fn firstPatchEndingAfter(patches: []const Patch, offset: usize) usize {
    var low: usize = 0;
    var high = patches.len;
    while (low < high) {
        const middle = low + (high - low) / 2;
        const metadata_patch = patches[middle];
        if (metadata_patch.offset + metadata_patch.len <= offset)
            low = middle + 1
        else
            high = middle;
    }
    return low;
}

fn normalizeZip32Plan(
    allocator: std.mem.Allocator,
    patches: *std.ArrayList(Patch),
    source: Source,
    end: End,
) InitError!Directory {
    if (end.disk != source.partCount() - 1 or end.central_disk >= source.partCount() or
        end.entries_on_disk > end.entry_count)
        return error.InvalidZipDiskOrder;
    const directory: Directory = .{
        .disk = end.central_disk,
        .offset = end.central_offset,
        .size = end.central_size,
        .entry_count = end.entry_count,
    };
    const virtual_central = try source.diskOffset(directory.disk, directory.offset);
    if (virtual_central >= std.math.maxInt(u32)) return error.UnsupportedZipFeature;
    try appendIntPatch(allocator, patches, u16, end.offset + 4, 0);
    try appendIntPatch(allocator, patches, u16, end.offset + 6, 0);
    try appendIntPatch(allocator, patches, u16, end.offset + 8, end.entry_count);
    try appendIntPatch(
        allocator,
        patches,
        u32,
        end.offset + 16,
        @intCast(virtual_central),
    );
    return directory;
}

fn normalizeZip64Plan(
    allocator: std.mem.Allocator,
    patches: *std.ArrayList(Patch),
    source: Source,
    end: End,
) InitError!Directory {
    if (end.offset < wire.zip64_end_of_central_locator_len)
        return error.InvalidZipArchive;
    const locator_offset = end.offset - wire.zip64_end_of_central_locator_len;
    if (try source.readInt(u32, locator_offset) !=
        wire.zip64_end_of_central_locator_signature)
        return error.InvalidZipArchive;
    const zip64_disk = try source.readInt(u32, locator_offset + 4);
    const zip64_offset_on_disk = try source.readInt(u64, locator_offset + 8);
    const disk_count = try source.readInt(u32, locator_offset + 16);
    if (zip64_disk >= source.partCount() or disk_count != source.partCount())
        return error.InvalidZipDiskOrder;
    const zip64_offset = try source.diskOffset(
        @intCast(zip64_disk),
        try u64ToUsize(zip64_offset_on_disk),
    );
    _ = try checkedEnd(zip64_offset, wire.zip64_end_of_central_len, locator_offset);
    if (try source.readInt(u32, zip64_offset) != wire.zip64_end_of_central_signature)
        return error.InvalidZipArchive;
    const payload_len = try u64ToUsize(try source.readInt(u64, zip64_offset + 4));
    if (payload_len < 44 or
        try checkedEnd(
            zip64_offset,
            try checkedAdd(12, payload_len),
            locator_offset,
        ) != locator_offset)
        return error.InvalidZipArchive;
    const disk = try source.readInt(u32, zip64_offset + 16);
    const central_disk = try source.readInt(u32, zip64_offset + 20);
    const entries_on_disk = try source.readInt(u64, zip64_offset + 24);
    const entry_count = try source.readInt(u64, zip64_offset + 32);
    const central_size = try source.readInt(u64, zip64_offset + 40);
    const central_offset_on_disk = try source.readInt(u64, zip64_offset + 48);
    if (disk != source.partCount() - 1 or central_disk >= source.partCount() or
        entries_on_disk > entry_count)
        return error.InvalidZipDiskOrder;
    const virtual_central = try source.diskOffset(
        @intCast(central_disk),
        try u64ToUsize(central_offset_on_disk),
    );

    try appendIntPatch(allocator, patches, u32, zip64_offset + 16, 0);
    try appendIntPatch(allocator, patches, u32, zip64_offset + 20, 0);
    try appendIntPatch(allocator, patches, u64, zip64_offset + 24, entry_count);
    try appendIntPatch(allocator, patches, u64, zip64_offset + 48, virtual_central);
    try appendIntPatch(allocator, patches, u32, locator_offset + 4, 0);
    try appendIntPatch(allocator, patches, u64, locator_offset + 8, zip64_offset);
    try appendIntPatch(allocator, patches, u32, locator_offset + 16, 1);
    if (end.disk != std.math.maxInt(u16))
        try appendIntPatch(allocator, patches, u16, end.offset + 4, 0);
    if (end.central_disk != std.math.maxInt(u16))
        try appendIntPatch(allocator, patches, u16, end.offset + 6, 0);
    if (end.entries_on_disk != std.math.maxInt(u16))
        try appendIntPatch(
            allocator,
            patches,
            u16,
            end.offset + 8,
            if (entry_count >= std.math.maxInt(u16))
                std.math.maxInt(u16)
            else
                @intCast(entry_count),
        );
    if (end.central_offset != std.math.maxInt(u32))
        try appendIntPatch(
            allocator,
            patches,
            u32,
            end.offset + 16,
            if (virtual_central >= std.math.maxInt(u32))
                std.math.maxInt(u32)
            else
                @intCast(virtual_central),
        );
    return .{
        .disk = @intCast(central_disk),
        .offset = try u64ToUsize(central_offset_on_disk),
        .size = try u64ToUsize(central_size),
        .entry_count = try u64ToUsize(entry_count),
    };
}

fn normalizeCentralEntryPlan(
    allocator: std.mem.Allocator,
    patches: *std.ArrayList(Patch),
    source: Source,
    offset: usize,
    central_end: usize,
) InitError!CentralResult {
    _ = try checkedEnd(offset, wire.central_file_header_len, central_end);
    if (try source.readInt(u32, offset) != wire.central_file_signature)
        return error.InvalidZipArchive;
    const name_len: usize = try source.readInt(u16, offset + 28);
    const extra_len: usize = try source.readInt(u16, offset + 30);
    const comment_len: usize = try source.readInt(u16, offset + 32);
    const variable_len = try checkedAdd(name_len, try checkedAdd(extra_len, comment_len));
    const variable_offset = offset + wire.central_file_header_len;
    const next = try checkedEnd(variable_offset, variable_len, central_end);
    const extra_offset = try checkedAdd(variable_offset, name_len);
    const extra_end = try checkedEnd(extra_offset, extra_len, next);

    const disk_legacy = try source.readInt(u16, offset + 34);
    const local_legacy = try source.readInt(u32, offset + 42);
    var disk: usize = disk_legacy;
    var local_offset: usize = local_legacy;
    var zip64_local_offset_pos: ?usize = null;
    var zip64_disk_pos: ?usize = null;
    if (disk_legacy == std.math.maxInt(u16) or local_legacy == std.math.maxInt(u32)) {
        const zip64 = try findExtra(source, extra_offset, extra_end, wire.zip64_extra_id) orelse
            return error.InvalidZipArchive;
        var payload_cursor: usize = 0;
        if (try source.readInt(u32, offset + 24) == std.math.maxInt(u32))
            payload_cursor = try checkedEnd(payload_cursor, 8, zip64.payload_len);
        if (try source.readInt(u32, offset + 20) == std.math.maxInt(u32))
            payload_cursor = try checkedEnd(payload_cursor, 8, zip64.payload_len);
        if (local_legacy == std.math.maxInt(u32)) {
            const value_end = try checkedEnd(payload_cursor, 8, zip64.payload_len);
            zip64_local_offset_pos = try checkedAdd(zip64.payload_offset, payload_cursor);
            local_offset = try u64ToUsize(try source.readInt(
                u64,
                zip64.payload_offset + payload_cursor,
            ));
            payload_cursor = value_end;
        }
        if (disk_legacy == std.math.maxInt(u16)) {
            _ = try checkedEnd(payload_cursor, 4, zip64.payload_len);
            zip64_disk_pos = try checkedAdd(zip64.payload_offset, payload_cursor);
            disk = try source.readInt(u32, zip64.payload_offset + payload_cursor);
        }
    }
    const virtual_local = try source.diskOffset(disk, local_offset);
    _ = try checkedEnd(virtual_local, 4, offset);
    if (try source.readInt(u32, virtual_local) != wire.local_file_signature)
        return error.InvalidZipDiskOrder;
    if (zip64_local_offset_pos) |position|
        try appendIntPatch(allocator, patches, u64, position, virtual_local)
    else if (virtual_local < std.math.maxInt(u32))
        try appendIntPatch(allocator, patches, u32, offset + 42, @intCast(virtual_local))
    else
        return error.UnsupportedZipFeature;
    if (zip64_disk_pos) |position|
        try appendIntPatch(allocator, patches, u32, position, 0)
    else
        try appendIntPatch(allocator, patches, u16, offset + 34, 0);
    return .{ .next = next, .local_offset = virtual_local };
}

const Extra = struct {
    payload_offset: usize,
    payload_len: usize,
};

fn findExtra(
    source: Source,
    extra_offset: usize,
    extra_end: usize,
    wanted: u16,
) Error!?Extra {
    var cursor = extra_offset;
    var result: ?Extra = null;
    while (cursor < extra_end) {
        const payload_offset = try checkedEnd(cursor, 4, extra_end);
        const id = try source.readInt(u16, cursor);
        const len: usize = try source.readInt(u16, cursor + 2);
        const end = try checkedEnd(payload_offset, len, extra_end);
        if (id == wanted) {
            if (result != null) return error.InvalidZipArchive;
            result = .{ .payload_offset = payload_offset, .payload_len = len };
        }
        cursor = end;
    }
    return result;
}

fn parseEnd(allocator: std.mem.Allocator, source: Source) InitError!End {
    const last_disk = source.partCount() - 1;
    const last_len = source.partLen(last_disk);
    const last_base = source.bases[last_disk];
    if (last_len < wire.end_of_central_len) return error.InvalidZipArchive;
    const search_len = @min(
        last_len,
        wire.end_of_central_len + @as(usize, std.math.maxInt(u16)),
    );
    const search = try allocator.alloc(u8, search_len);
    defer allocator.free(search);
    const lower = last_len - search_len;
    try source.copyExact(last_base + lower, search);
    var offset = search.len - wire.end_of_central_len;
    while (true) {
        if (std.mem.readInt(u32, search[offset..][0..4], .little) ==
            wire.end_of_central_signature)
        {
            const comment_len = std.mem.readInt(u16, search[offset + 20 ..][0..2], .little);
            const record_len = wire.end_of_central_len + @as(usize, comment_len);
            if (record_len <= search.len and offset == search.len - record_len) {
                const absolute = try checkedAdd(last_base, lower + offset);
                return .{
                    .offset = absolute,
                    .disk = std.mem.readInt(u16, search[offset + 4 ..][0..2], .little),
                    .central_disk = std.mem.readInt(u16, search[offset + 6 ..][0..2], .little),
                    .entries_on_disk = std.mem.readInt(u16, search[offset + 8 ..][0..2], .little),
                    .entry_count = std.mem.readInt(u16, search[offset + 10 ..][0..2], .little),
                    .central_size = std.mem.readInt(u32, search[offset + 12 ..][0..4], .little),
                    .central_offset = std.mem.readInt(u32, search[offset + 16 ..][0..4], .little),
                };
            }
        }
        if (offset == 0) break;
        offset -= 1;
    }
    return error.InvalidZipArchive;
}

fn appendIntPatch(
    allocator: std.mem.Allocator,
    patches: *std.ArrayList(Patch),
    comptime T: type,
    offset: usize,
    value: T,
) std.mem.Allocator.Error!void {
    var metadata_patch: Patch = .{
        .offset = offset,
        .len = @sizeOf(T),
    };
    std.mem.writeInt(T, metadata_patch.bytes[0..@sizeOf(T)], value, .little);
    try patches.append(allocator, metadata_patch);
}

fn patchLessThan(_: void, left: Patch, right: Patch) bool {
    return left.offset < right.offset;
}

fn hasZip64Sentinel(end: End) bool {
    return end.disk == std.math.maxInt(u16) or
        end.central_disk == std.math.maxInt(u16) or
        end.entries_on_disk == std.math.maxInt(u16) or
        end.entry_count == std.math.maxInt(u16) or
        end.central_size == std.math.maxInt(u32) or
        end.central_offset == std.math.maxInt(u32);
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}

fn u64ToUsize(value: u64) Error!usize {
    return std.math.cast(usize, value) orelse error.UnsupportedZipFeature;
}
