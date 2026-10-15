//! Allocating standard split/multi-disk ZIP writer.
//!
//! Local headers, descriptors, central headers, and archive endings remain
//! indivisible. Only member payload bytes may cross a part boundary, matching
//! the layouts emitted by Info-ZIP.

const std = @import("std");
const archive_records = @import("incremental_reader/archive_records.zig");
const records = @import("records.zig");
const wire = @import("wire.zig");
const writer = @import("writer.zig");

pub const Error = writer.Error || records.Error || archive_records.Error || error{
    InvalidZipArchive,
    InvalidZipSplitSize,
    ZipSplitLimitExceeded,
    OutputLimitExceeded,
    IntegerOverflow,
};

const AllocError = Error || std.mem.Allocator.Error;

pub const Options = struct {
    zip_options: writer.EncodeOptions = .{},
    max_part_size: usize = 64 * 1024 * 1024,
    max_archive_size: usize = std.math.maxInt(usize),
    /// Disk numbers remain in the legacy central field in this owned slice.
    max_parts: usize = std.math.maxInt(u16),
};

pub const EncodedArchive = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    parts: []const []const u8,

    pub fn deinit(self: *EncodedArchive) void {
        self.allocator.free(self.parts);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }
};

const EntryLayout = struct {
    local_offset: usize,
    data_offset: usize,
    payload_end: usize,
    record_end: usize,
    central_offset: usize,
    central_end: usize,
};

const Planner = struct {
    allocator: std.mem.Allocator,
    max_part_size: usize,
    max_parts: usize,
    bases: std.ArrayList(usize) = .empty,
    position: usize = 0,

    fn init(
        allocator: std.mem.Allocator,
        max_part_size: usize,
        max_parts: usize,
    ) AllocError!Planner {
        if (max_part_size == 0) return error.InvalidZipSplitSize;
        if (max_parts == 0 or max_parts > std.math.maxInt(u16))
            return error.ZipSplitLimitExceeded;
        var self: Planner = .{
            .allocator = allocator,
            .max_part_size = max_part_size,
            .max_parts = max_parts,
        };
        errdefer self.bases.deinit(allocator);
        try self.bases.append(allocator, 0);
        return self;
    }

    fn deinit(self: *Planner) void {
        self.bases.deinit(self.allocator);
        self.* = undefined;
    }

    fn placeAtomic(self: *Planner, start: usize, end: usize) AllocError!void {
        if (start != self.position or end < start) return error.InvalidZipArchive;
        const len = end - start;
        if (len > self.max_part_size) return error.InvalidZipSplitSize;
        const used = start - self.bases.items[self.bases.items.len - 1];
        if (used > self.max_part_size) return error.InvalidZipArchive;
        if (len > self.max_part_size - used) try self.startPart(start);
        self.position = end;
    }

    fn placePayload(self: *Planner, start: usize, end: usize) AllocError!void {
        if (start != self.position or end < start) return error.InvalidZipArchive;
        while (self.position < end) {
            const base = self.bases.items[self.bases.items.len - 1];
            const used = self.position - base;
            if (used > self.max_part_size) return error.InvalidZipArchive;
            const room = self.max_part_size - used;
            if (room == 0) {
                try self.startPart(self.position);
                continue;
            }
            self.position += @min(room, end - self.position);
        }
    }

    fn startPart(self: *Planner, offset: usize) AllocError!void {
        if (offset == self.bases.items[self.bases.items.len - 1])
            return error.InvalidZipSplitSize;
        if (self.bases.items.len == self.max_parts)
            return error.ZipSplitLimitExceeded;
        try self.bases.append(self.allocator, offset);
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    entries: []const writer.EncodeEntry,
    options: Options,
) (Error || std.mem.Allocator.Error)!EncodedArchive {
    var archive: std.ArrayList(u8) = .empty;
    errdefer archive.deinit(allocator);
    try wire.appendU32(allocator, &archive, wire.data_descriptor_signature);
    _ = try writer.encodeAppend(allocator, &archive, entries, options.zip_options);
    if (archive.items.len > options.max_archive_size)
        return error.OutputLimitExceeded;

    const directory = try records.parseDirectory(archive.items);
    const layouts = try parseLayouts(allocator, archive.items, directory);
    defer allocator.free(layouts);
    var planner = try Planner.init(
        allocator,
        options.max_part_size,
        options.max_parts,
    );
    defer planner.deinit();
    try planner.placeAtomic(0, 4);
    for (layouts) |layout| {
        try planner.placeAtomic(layout.local_offset, layout.data_offset);
        try planner.placePayload(layout.data_offset, layout.payload_end);
        if (layout.record_end != layout.payload_end)
            try planner.placeAtomic(layout.payload_end, layout.record_end);
    }
    for (layouts) |layout|
        try planner.placeAtomic(layout.central_offset, layout.central_end);
    const central_end = try checkedEnd(
        directory.central_directory_offset,
        directory.central_directory_size,
        archive.items.len,
    );
    try planner.placeAtomic(central_end, archive.items.len);
    if (planner.position != archive.items.len) return error.InvalidZipArchive;

    try rewriteMetadata(
        archive.items,
        directory,
        layouts,
        planner.bases.items,
    );
    const bytes = try archive.toOwnedSlice(allocator);
    errdefer allocator.free(bytes);
    const parts = try allocator.alloc([]const u8, planner.bases.items.len);
    errdefer allocator.free(parts);
    for (parts, planner.bases.items, 0..) |*part, base, index| {
        const end = if (index + 1 < planner.bases.items.len)
            planner.bases.items[index + 1]
        else
            bytes.len;
        part.* = bytes[base..end];
    }
    return .{
        .allocator = allocator,
        .bytes = bytes,
        .parts = parts,
    };
}

fn parseLayouts(
    allocator: std.mem.Allocator,
    bytes: []const u8,
    directory: records.Directory,
) (Error || std.mem.Allocator.Error)![]EntryLayout {
    const layouts = try allocator.alloc(EntryLayout, directory.entry_count);
    errdefer allocator.free(layouts);
    const central_limit = try checkedEnd(
        directory.central_directory_offset,
        directory.central_directory_size,
        bytes.len,
    );
    var central_offset = directory.central_directory_offset;
    var expected_local: usize = 4;
    for (layouts) |*layout| {
        _ = try checkedEnd(
            central_offset,
            wire.central_file_header_len,
            central_limit,
        );
        const central_fixed: *const [wire.central_file_header_len]u8 =
            bytes[central_offset..][0..wire.central_file_header_len];
        const central_len = try archive_records.centralEncodedLen(central_fixed);
        const central_end = try checkedEnd(central_offset, central_len, central_limit);
        const central = try archive_records.parseCentral(bytes[central_offset..central_end]);
        if (central.local_header_offset != expected_local)
            return error.InvalidZipArchive;
        _ = try checkedEnd(
            central.local_header_offset,
            wire.local_file_header_len,
            central_offset,
        );
        const local_fixed: *const [wire.local_file_header_len]u8 =
            bytes[central.local_header_offset..][0..wire.local_file_header_len];
        const local_len = try archive_records.localEncodedLen(local_fixed);
        const data_offset = try checkedEnd(
            central.local_header_offset,
            local_len,
            central_offset,
        );
        const local = try archive_records.parseLocal(
            bytes[central.local_header_offset..data_offset],
        );
        if (!std.mem.eql(u8, local.name, central.name) or
            local.method != central.method or
            local.flags != central.flags or
            local.zip64 != central.zip64)
            return error.InvalidZipArchive;
        const payload_end = try checkedEnd(
            data_offset,
            central.compressed_size,
            central_offset,
        );
        const descriptor_len: usize = if (central.flags & wire.descriptor_flag == 0)
            0
        else if (central.zip64)
            wire.zip64_data_descriptor_len
        else
            wire.data_descriptor_len;
        const record_end = try checkedEnd(payload_end, descriptor_len, central_offset);
        layout.* = .{
            .local_offset = central.local_header_offset,
            .data_offset = data_offset,
            .payload_end = payload_end,
            .record_end = record_end,
            .central_offset = central_offset,
            .central_end = central_end,
        };
        expected_local = record_end;
        central_offset = central_end;
    }
    if (central_offset != central_limit or expected_local != directory.central_directory_offset)
        return error.InvalidZipArchive;
    return layouts;
}

fn rewriteMetadata(
    bytes: []u8,
    directory: records.Directory,
    layouts: []const EntryLayout,
    bases: []const usize,
) Error!void {
    for (layouts) |layout| {
        const disk = diskForOffset(bases, layout.local_offset);
        const local_offset = layout.local_offset - bases[disk];
        if (disk >= std.math.maxInt(u16)) return error.ZipSplitLimitExceeded;
        std.mem.writeInt(
            u16,
            bytes[layout.central_offset + 34 ..][0..2],
            @intCast(disk),
            .little,
        );
        const legacy_local = std.mem.readInt(
            u32,
            bytes[layout.central_offset + 42 ..][0..4],
            .little,
        );
        if (legacy_local == std.math.maxInt(u32)) {
            const position = try centralZip64LocalOffsetPosition(
                bytes,
                layout.central_offset,
                layout.central_end,
            );
            std.mem.writeInt(u64, bytes[position..][0..8], local_offset, .little);
        } else {
            if (local_offset >= std.math.maxInt(u32))
                return error.ZipSplitLimitExceeded;
            std.mem.writeInt(
                u32,
                bytes[layout.central_offset + 42 ..][0..4],
                @intCast(local_offset),
                .little,
            );
        }
    }

    const central_disk = diskForOffset(bases, directory.central_directory_offset);
    const central_offset = directory.central_directory_offset - bases[central_disk];
    const end_offset = bytes.len - wire.end_of_central_len - directory.comment.len;
    const end_disk = diskForOffset(bases, end_offset);
    var entries_on_end_disk: usize = 0;
    for (layouts) |layout| {
        if (diskForOffset(bases, layout.central_offset) == end_disk)
            entries_on_end_disk += 1;
    }
    if (central_disk >= std.math.maxInt(u16) or end_disk >= std.math.maxInt(u16))
        return error.ZipSplitLimitExceeded;

    if (directory.zip64) {
        if (end_offset < wire.zip64_end_of_central_locator_len)
            return error.InvalidZipArchive;
        const locator_offset = end_offset - wire.zip64_end_of_central_locator_len;
        const zip64_offset = std.math.cast(
            usize,
            std.mem.readInt(u64, bytes[locator_offset + 8 ..][0..8], .little),
        ) orelse return error.ZipSplitLimitExceeded;
        if (zip64_offset >= locator_offset or
            std.mem.readInt(u32, bytes[zip64_offset..][0..4], .little) !=
                wire.zip64_end_of_central_signature)
            return error.InvalidZipArchive;
        const zip64_disk = diskForOffset(bases, zip64_offset);
        std.mem.writeInt(u32, bytes[zip64_offset + 16 ..][0..4], @intCast(zip64_disk), .little);
        std.mem.writeInt(u32, bytes[zip64_offset + 20 ..][0..4], @intCast(central_disk), .little);
        std.mem.writeInt(u64, bytes[zip64_offset + 24 ..][0..8], entries_on_end_disk, .little);
        std.mem.writeInt(u64, bytes[zip64_offset + 48 ..][0..8], central_offset, .little);
        std.mem.writeInt(u32, bytes[locator_offset + 4 ..][0..4], @intCast(zip64_disk), .little);
        std.mem.writeInt(
            u64,
            bytes[locator_offset + 8 ..][0..8],
            zip64_offset - bases[zip64_disk],
            .little,
        );
        std.mem.writeInt(u32, bytes[locator_offset + 16 ..][0..4], @intCast(bases.len), .little);
        if (std.mem.readInt(u16, bytes[end_offset + 4 ..][0..2], .little) !=
            std.math.maxInt(u16))
            std.mem.writeInt(u16, bytes[end_offset + 4 ..][0..2], @intCast(end_disk), .little);
        if (std.mem.readInt(u16, bytes[end_offset + 6 ..][0..2], .little) !=
            std.math.maxInt(u16))
            std.mem.writeInt(u16, bytes[end_offset + 6 ..][0..2], @intCast(central_disk), .little);
        if (std.mem.readInt(u16, bytes[end_offset + 8 ..][0..2], .little) !=
            std.math.maxInt(u16))
            std.mem.writeInt(
                u16,
                bytes[end_offset + 8 ..][0..2],
                if (entries_on_end_disk >= std.math.maxInt(u16))
                    std.math.maxInt(u16)
                else
                    @intCast(entries_on_end_disk),
                .little,
            );
        if (std.mem.readInt(u32, bytes[end_offset + 16 ..][0..4], .little) !=
            std.math.maxInt(u32))
            std.mem.writeInt(
                u32,
                bytes[end_offset + 16 ..][0..4],
                if (central_offset >= std.math.maxInt(u32))
                    std.math.maxInt(u32)
                else
                    @intCast(central_offset),
                .little,
            );
    } else {
        if (entries_on_end_disk >= std.math.maxInt(u16) or
            central_offset >= std.math.maxInt(u32))
            return error.ZipSplitLimitExceeded;
        std.mem.writeInt(u16, bytes[end_offset + 4 ..][0..2], @intCast(end_disk), .little);
        std.mem.writeInt(u16, bytes[end_offset + 6 ..][0..2], @intCast(central_disk), .little);
        std.mem.writeInt(u16, bytes[end_offset + 8 ..][0..2], @intCast(entries_on_end_disk), .little);
        std.mem.writeInt(u32, bytes[end_offset + 16 ..][0..4], @intCast(central_offset), .little);
    }
}

fn centralZip64LocalOffsetPosition(
    bytes: []const u8,
    central_offset: usize,
    central_end: usize,
) Error!usize {
    const name_len: usize = std.mem.readInt(u16, bytes[central_offset + 28 ..][0..2], .little);
    const extra_len: usize = std.mem.readInt(u16, bytes[central_offset + 30 ..][0..2], .little);
    const extra_offset = central_offset + wire.central_file_header_len + name_len;
    const extra_end = try checkedEnd(extra_offset, extra_len, central_end);
    var cursor = extra_offset;
    var zip64_payload: ?struct { offset: usize, len: usize } = null;
    while (cursor < extra_end) {
        const payload_offset = try checkedEnd(cursor, 4, extra_end);
        const id = std.mem.readInt(u16, bytes[cursor..][0..2], .little);
        const len: usize = std.mem.readInt(u16, bytes[cursor + 2 ..][0..2], .little);
        const next = try checkedEnd(payload_offset, len, extra_end);
        if (id == wire.zip64_extra_id) {
            if (zip64_payload != null) return error.InvalidZipArchive;
            zip64_payload = .{ .offset = payload_offset, .len = len };
        }
        cursor = next;
    }
    const zip64 = zip64_payload orelse return error.InvalidZipArchive;
    var payload_cursor: usize = 0;
    if (std.mem.readInt(u32, bytes[central_offset + 24 ..][0..4], .little) ==
        std.math.maxInt(u32))
        payload_cursor = try checkedEnd(payload_cursor, 8, zip64.len);
    if (std.mem.readInt(u32, bytes[central_offset + 20 ..][0..4], .little) ==
        std.math.maxInt(u32))
        payload_cursor = try checkedEnd(payload_cursor, 8, zip64.len);
    _ = try checkedEnd(payload_cursor, 8, zip64.len);
    return checkedAdd(zip64.offset, payload_cursor);
}

fn diskForOffset(bases: []const usize, offset: usize) usize {
    std.debug.assert(bases.len != 0 and bases[0] == 0);
    var low: usize = 0;
    var high = bases.len;
    while (low + 1 < high) {
        const middle = low + (high - low) / 2;
        if (bases[middle] <= offset)
            low = middle
        else
            high = middle;
    }
    return low;
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn checkedEnd(start: usize, len: usize, limit: usize) Error!usize {
    const end = try checkedAdd(start, len);
    if (end > limit) return error.InvalidZipArchive;
    return end;
}
