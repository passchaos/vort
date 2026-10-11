const std = @import("std");
const codec = @import("codec.zig");
const format = @import("format.zig");
const rvz_pack = @import("rvz_pack.zig");

pub const Error = format.Error || codec.Error || rvz_pack.Error ||
    std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_header2_bytes: usize = 4096,
    max_raw_entries: usize = 1 << 20,
    max_group_entries: usize = 1 << 24,
    max_chunk_size: usize = 64 * 1024 * 1024,
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_group_stored_bytes: usize = 128 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header1: format.Header1,
    header2: format.Header2,
    raw_entries: []format.RawEntry,
    groups: []format.GroupEntry,
    max_dictionary_size: usize,

    pub fn initAlloc(
        allocator: std.mem.Allocator,
        input: []const u8,
        options: OpenOptions,
    ) Error!Archive {
        const header1 = try format.parseHeader1(input);
        if (header1.header2_bytes > options.max_header2_bytes)
            return error.OutputLimitExceeded;
        const header2 = try format.parseHeader2(input, header1);
        if (header2.chunk_size > options.max_chunk_size or
            header2.raw_count > options.max_raw_entries or
            header2.group_count > options.max_group_entries or
            header2.raw_bytes > options.max_metadata_bytes or
            header2.group_bytes > options.max_metadata_bytes)
            return error.OutputLimitExceeded;
        if (header2.partition_count != 0)
            return error.UnsupportedWiaFeature;
        if (header2.partition_bytes < format.partition_entry_size)
            return error.InvalidWia;
        try validateExtent(
            input.len,
            header2.partition_offset,
            std.math.mul(
                usize,
                header2.partition_count,
                header2.partition_bytes,
            ) catch return error.IntegerOverflow,
        );
        const partition_offset = std.math.cast(
            usize,
            header2.partition_offset,
        ) orelse return error.IntegerOverflow;
        const partition_len = header2.partition_count * header2.partition_bytes;
        var partition_hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(
            input[partition_offset..][0..partition_len],
            &partition_hash,
            .{},
        );
        if (!std.mem.eql(u8, &partition_hash, &header2.partition_hash))
            return error.ChecksumMismatch;

        const compressor_data = header2.compressor_data[0..header2.compressor_data_len];
        const raw_table_decoded_len = std.math.mul(
            usize,
            header2.raw_count,
            format.raw_entry_size,
        ) catch return error.IntegerOverflow;
        const raw_table = try decodeExtent(
            allocator,
            input,
            header2.raw_offset,
            header2.raw_bytes,
            header2.compression,
            compressor_data,
            raw_table_decoded_len,
            options.max_dictionary_size,
        );
        defer allocator.free(raw_table);
        const raw_entries = try allocator.alloc(format.RawEntry, header2.raw_count);
        errdefer allocator.free(raw_entries);
        for (raw_entries, 0..) |*entry, index|
            entry.* = try format.parseRawEntry(
                raw_table[index * format.raw_entry_size ..][0..format.raw_entry_size],
            );

        const group_entry_size = header1.container.groupEntrySize();
        const group_table_decoded_len = std.math.mul(
            usize,
            header2.group_count,
            group_entry_size,
        ) catch return error.IntegerOverflow;
        const group_table = try decodeExtent(
            allocator,
            input,
            header2.group_offset,
            header2.group_bytes,
            header2.compression,
            compressor_data,
            group_table_decoded_len,
            options.max_dictionary_size,
        );
        defer allocator.free(group_table);
        const groups = try allocator.alloc(format.GroupEntry, header2.group_count);
        errdefer allocator.free(groups);
        for (groups, 0..) |*entry, index|
            entry.* = try format.parseGroupEntry(
                header1.container,
                group_table[index * group_entry_size ..][0..group_entry_size],
            );

        var logical_cursor: u64 = format.disc_header_size;
        for (raw_entries) |entry| {
            if (entry.data_size == 0 or entry.data_offset != logical_cursor)
                return error.InvalidWia;
            const end = std.math.add(u64, entry.data_offset, entry.data_size) catch
                return error.IntegerOverflow;
            if (end > header1.logical_size) return error.InvalidWia;
            const skipped = entry.data_offset % format.wii_block_size;
            const adjusted_size = std.math.add(u64, entry.data_size, skipped) catch
                return error.IntegerOverflow;
            const expected_groups = std.math.divCeil(
                u64,
                adjusted_size,
                header2.chunk_size,
            ) catch return error.IntegerOverflow;
            if (entry.group_count != expected_groups or
                entry.group_index > groups.len or
                entry.group_count > groups.len - entry.group_index)
                return error.InvalidWia;
            logical_cursor = end;
        }
        if (header1.logical_size > format.disc_header_size and
            logical_cursor != header1.logical_size)
            return error.InvalidWia;
        for (groups) |group| {
            if (group.stored_size == 0) {
                if (group.rvz_packed_size != 0) return error.InvalidWia;
                continue;
            }
            if (group.stored_size > options.max_group_stored_bytes)
                return error.OutputLimitExceeded;
            try validateExtent(input.len, group.data_offset, group.stored_size);
            if (group.rvz_packed_size > options.max_group_stored_bytes)
                return error.OutputLimitExceeded;
        }
        return .{
            .allocator = allocator,
            .bytes = input,
            .header1 = header1,
            .header2 = header2,
            .raw_entries = raw_entries,
            .groups = groups,
            .max_dictionary_size = options.max_dictionary_size,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.groups);
        self.allocator.free(self.raw_entries);
        self.* = undefined;
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.header1.logical_size) orelse
            return error.OutputLimitExceeded;
        if (size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, size);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, 0, output);
        return output;
    }

    pub fn readRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.readRangeInto(allocator, offset, output);
        return output;
    }

    pub fn readRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (end > self.header1.logical_size) return error.RangeOutOfBounds;
        var position = offset;
        var written: usize = 0;
        if (position < format.disc_header_size and written < output.len) {
            const length = @min(
                output.len,
                format.disc_header_size - position,
            );
            @memcpy(
                output[0..length],
                self.header2.disc_header[position..][0..length],
            );
            position += length;
            written += length;
        }
        while (written < output.len) {
            const entry = self.findRawEntry(position) orelse
                return error.InvalidWia;
            const skipped = entry.data_offset % format.wii_block_size;
            const adjusted_offset = entry.data_offset - skipped;
            const adjusted_size = entry.data_size + skipped;
            const relative = position - adjusted_offset;
            const local_group = relative / self.header2.chunk_size;
            if (local_group >= entry.group_count) return error.InvalidWia;
            const group_index = entry.group_index + local_group;
            const group_offset = local_group * @as(usize, self.header2.chunk_size);
            const expected_size = @min(
                @as(usize, self.header2.chunk_size),
                @as(usize, @intCast(adjusted_size)) - group_offset,
            );
            const decoded = try self.decodeGroupAlloc(
                allocator,
                group_index,
                expected_size,
                group_offset,
            );
            defer allocator.free(decoded);
            const within_group = relative - group_offset;
            const length = @min(
                output.len - written,
                decoded.len - within_group,
            );
            @memcpy(
                output[written..][0..length],
                decoded[within_group..][0..length],
            );
            position += length;
            written += length;
        }
    }

    fn decodeGroupAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        group_index: usize,
        expected_size: usize,
        data_offset: usize,
    ) Error![]u8 {
        if (group_index >= self.groups.len) return error.InvalidWia;
        const group = self.groups[group_index];
        if (group.stored_size == 0) {
            const output = try allocator.alloc(u8, expected_size);
            @memset(output, 0);
            return output;
        }
        const offset = std.math.cast(usize, group.data_offset) orelse
            return error.IntegerOverflow;
        const stored = self.bytes[offset..][0..group.stored_size];
        const compression = if (self.header1.container == .rvz and
            !group.compressed)
            format.Compression.none
        else
            self.header2.compression;
        const primary_size = if (group.rvz_packed_size == 0)
            expected_size
        else
            group.rvz_packed_size;
        const primary = try codec.decodeAllocExact(
            allocator,
            stored,
            compression,
            self.header2.compressor_data[0..self.header2.compressor_data_len],
            primary_size,
            self.max_dictionary_size,
        );
        if (group.rvz_packed_size == 0) return primary;
        defer allocator.free(primary);
        return rvz_pack.decodeAllocExact(
            allocator,
            primary,
            expected_size,
            data_offset,
        );
    }

    fn findRawEntry(self: Archive, offset: usize) ?format.RawEntry {
        var low: usize = 0;
        var high = self.raw_entries.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            const entry = self.raw_entries[mid];
            if (offset < entry.data_offset) {
                high = mid;
            } else if (offset >= entry.data_offset + entry.data_size) {
                low = mid + 1;
            } else {
                return entry;
            }
        }
        return null;
    }
};

fn validateExtent(total: usize, offset_u64: u64, size: usize) Error!void {
    const offset = std.math.cast(usize, offset_u64) orelse
        return error.IntegerOverflow;
    const end = std.math.add(usize, offset, size) catch
        return error.IntegerOverflow;
    if (end > total) return error.TruncatedFrame;
}

fn decodeExtent(
    allocator: std.mem.Allocator,
    input: []const u8,
    offset_u64: u64,
    size: usize,
    compression: format.Compression,
    compressor_data: []const u8,
    expected_size: usize,
    max_dictionary_size: usize,
) Error![]u8 {
    try validateExtent(input.len, offset_u64, size);
    const offset = std.math.cast(usize, offset_u64) orelse
        return error.IntegerOverflow;
    return codec.decodeAllocExact(
        allocator,
        input[offset..][0..size],
        compression,
        compressor_data,
        expected_size,
        max_dictionary_size,
    );
}
