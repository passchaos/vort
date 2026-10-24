const std = @import("std");
const codec = @import("codec.zig");
const format = @import("format.zig");
const rvz_pack = @import("rvz_pack.zig");
const wii = @import("wii_partition.zig");

pub const Error = format.Error || codec.Error || rvz_pack.Error || wii.Error ||
    std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_header2_bytes: usize = 4096,
    max_partition_entries: usize = 1 << 20,
    max_partition_entry_size: usize = 4096,
    max_raw_entries: usize = 1 << 20,
    max_group_entries: usize = 1 << 24,
    max_chunk_size: usize = 64 * 1024 * 1024,
    max_metadata_bytes: usize = 256 * 1024 * 1024,
    max_group_stored_bytes: usize = 128 * 1024 * 1024,
    max_dictionary_size: usize = 64 * 1024 * 1024,
    max_hash_exceptions_per_list: usize = wii.max_exceptions_per_list,
};

const DataKind = union(enum) {
    raw: usize,
    partition: struct { partition: usize, data: usize },
};

const DataRange = struct {
    start: u64,
    end: u64,
    kind: DataKind,
};

const DecodedPartitionChunk = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    exceptions: wii.ParsedExceptionLists,

    fn deinit(self: *DecodedPartitionChunk) void {
        self.exceptions.deinit();
        self.allocator.free(self.data);
        self.* = undefined;
    }
};

pub const Archive = struct {
    allocator: std.mem.Allocator,
    bytes: []const u8,
    header1: format.Header1,
    header2: format.Header2,
    partitions: []format.PartitionEntry,
    raw_entries: []format.RawEntry,
    groups: []format.GroupEntry,
    data_ranges: []DataRange,
    max_dictionary_size: usize,
    max_hash_exceptions_per_list: usize,

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
            header2.partition_count > options.max_partition_entries or
            header2.partition_bytes > options.max_partition_entry_size or
            header2.raw_count > options.max_raw_entries or
            header2.group_count > options.max_group_entries or
            header2.raw_bytes > options.max_metadata_bytes or
            header2.group_bytes > options.max_metadata_bytes)
            return error.OutputLimitExceeded;
        if (header2.partition_count != 0 and header2.partition_bytes < 16)
            return error.InvalidWia;
        const partition_len = std.math.mul(
            usize,
            header2.partition_count,
            header2.partition_bytes,
        ) catch return error.IntegerOverflow;
        try validateExtent(input.len, header2.partition_offset, partition_len);
        const partition_offset = std.math.cast(
            usize,
            header2.partition_offset,
        ) orelse return error.IntegerOverflow;
        var partition_hash: [20]u8 = undefined;
        std.crypto.hash.Sha1.hash(
            input[partition_offset..][0..partition_len],
            &partition_hash,
            .{},
        );
        if (!std.mem.eql(u8, &partition_hash, &header2.partition_hash))
            return error.ChecksumMismatch;
        const partitions = try allocator.alloc(
            format.PartitionEntry,
            header2.partition_count,
        );
        errdefer allocator.free(partitions);
        for (partitions, 0..) |*entry, index| {
            const start = partition_offset + index * header2.partition_bytes;
            entry.* = try format.parsePartitionEntry(
                input[start..][0..header2.partition_bytes],
            );
        }

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

        var ranges: std.ArrayList(DataRange) = .empty;
        errdefer ranges.deinit(allocator);
        for (raw_entries, 0..) |entry, raw_index| {
            if (entry.data_size == 0)
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
            try ranges.append(allocator, .{
                .start = entry.data_offset,
                .end = end,
                .kind = .{ .raw = raw_index },
            });
        }
        for (partitions, 0..) |partition, partition_index| {
            if (partition.data[0].sector_count == 0)
                return error.InvalidWia;
            const partition_start = partition.data[0].logicalOffset();
            var previous_end: u64 = 0;
            var non_empty: usize = 0;
            for (partition.data, 0..) |entry, data_index| {
                if (entry.sector_count == 0) continue;
                non_empty += 1;
                const start = entry.logicalOffset();
                const end = std.math.add(u64, start, entry.logicalSize()) catch
                    return error.IntegerOverflow;
                if (non_empty > 1 and start < previous_end)
                    return error.InvalidWia;
                if ((start - partition_start) % format.wii_group_size != 0)
                    return error.InvalidWia;
                const expected_groups = std.math.divCeil(
                    u64,
                    entry.logicalSize(),
                    header2.chunk_size,
                ) catch return error.IntegerOverflow;
                if (entry.group_count != expected_groups or
                    entry.group_index > groups.len or
                    entry.group_count > groups.len - entry.group_index)
                    return error.InvalidWia;
                try ranges.append(allocator, .{
                    .start = start,
                    .end = end,
                    .kind = .{ .partition = .{
                        .partition = partition_index,
                        .data = data_index,
                    } },
                });
                previous_end = end;
            }
            if (non_empty == 0) return error.InvalidWia;
        }
        std.mem.sort(DataRange, ranges.items, {}, dataRangeLessThan);
        var logical_cursor: u64 = format.disc_header_size;
        for (ranges.items) |range| {
            if (range.start != logical_cursor or range.end <= range.start or
                range.end > header1.logical_size)
                return error.InvalidWia;
            logical_cursor = range.end;
        }
        if (logical_cursor != header1.logical_size) return error.InvalidWia;
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
            .partitions = partitions,
            .raw_entries = raw_entries,
            .groups = groups,
            .data_ranges = try ranges.toOwnedSlice(allocator),
            .max_dictionary_size = options.max_dictionary_size,
            .max_hash_exceptions_per_list = options.max_hash_exceptions_per_list,
        };
    }

    pub fn deinit(self: *Archive) void {
        self.allocator.free(self.data_ranges);
        self.allocator.free(self.groups);
        self.allocator.free(self.raw_entries);
        self.allocator.free(self.partitions);
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
            const range = self.findDataRange(position) orelse
                return error.InvalidWia;
            switch (range.kind) {
                .raw => |raw_index| {
                    const entry = self.raw_entries[raw_index];
                    const skipped = entry.data_offset % format.wii_block_size;
                    const adjusted_offset = entry.data_offset - skipped;
                    const adjusted_size = entry.data_size + skipped;
                    const relative = position - adjusted_offset;
                    const local_group = relative / self.header2.chunk_size;
                    if (local_group >= entry.group_count) return error.InvalidWia;
                    const group_index = std.math.cast(usize, entry.group_index + local_group) orelse return error.InvalidWia;
                    const group_offset = std.math.cast(usize, local_group * self.header2.chunk_size) orelse return error.InvalidWia;
                    const chunk_size: usize = self.header2.chunk_size;
                    const remaining = if (std.math.cast(usize, adjusted_size)) |size|
                        size - group_offset
                    else
                        chunk_size;
                    const expected_size = @min(chunk_size, remaining);
                    const decoded = try self.decodeGroupAlloc(
                        allocator,
                        group_index,
                        expected_size,
                        group_offset,
                    );
                    defer allocator.free(decoded);
                    const within_group = std.math.cast(usize, relative - group_offset) orelse return error.InvalidWia;
                    if (within_group >= decoded.len) return error.InvalidWia;
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
                },
                .partition => |partition_ref| {
                    const partition = self.partitions[partition_ref.partition];
                    const partition_start = std.math.cast(
                        usize,
                        partition.data[0].logicalOffset(),
                    ) orelse return error.IntegerOverflow;
                    const relative = position - partition_start;
                    const encrypted_group_offset = std.mem.alignBackward(
                        usize,
                        relative,
                        format.wii_group_size,
                    );
                    const decoded = try self.reconstructPartitionGroupAlloc(
                        allocator,
                        partition_ref.partition,
                        encrypted_group_offset,
                    );
                    defer allocator.free(decoded);
                    const within_group = relative - encrypted_group_offset;
                    const range_remaining_u64 = range.end - position;
                    const range_remaining = std.math.cast(
                        usize,
                        range_remaining_u64,
                    ) orelse std.math.maxInt(usize);
                    const length = @min(
                        @min(output.len - written, decoded.len - within_group),
                        range_remaining,
                    );
                    @memcpy(
                        output[written..][0..length],
                        decoded[within_group..][0..length],
                    );
                    position += length;
                    written += length;
                },
            }
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

    fn reconstructPartitionGroupAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        partition_index: usize,
        encrypted_group_offset: usize,
    ) Error![]u8 {
        const partition = self.partitions[partition_index];
        const partition_start = partition.data[0].logicalOffset();
        const logical_group_start = std.math.add(
            u64,
            partition_start,
            encrypted_group_offset,
        ) catch return error.IntegerOverflow;
        var data_entry: ?format.PartitionDataEntry = null;
        for (partition.data) |candidate| {
            if (candidate.sector_count == 0) continue;
            const end = candidate.logicalOffset() + candidate.logicalSize();
            if (logical_group_start >= candidate.logicalOffset() and
                logical_group_start < end)
            {
                data_entry = candidate;
                break;
            }
        }
        const entry = data_entry orelse return error.InvalidWia;
        const entry_relative_raw = std.math.cast(
            usize,
            logical_group_start - entry.logicalOffset(),
        ) orelse return error.IntegerOverflow;
        const chunk_size: usize = self.header2.chunk_size;
        const sectors_per_chunk = chunk_size / format.wii_block_size;
        const decrypted_per_chunk = sectors_per_chunk * wii.block_data_size;
        const entry_decrypted_offset = std.math.mul(
            usize,
            entry.first_sector - partition.data[0].first_sector,
            wii.block_data_size,
        ) catch return error.IntegerOverflow;
        const decrypted_group = try allocator.alloc(u8, wii.group_data_size);
        defer allocator.free(decrypted_group);
        @memset(decrypted_group, 0);
        var exceptions: std.ArrayList(format.HashException) = .empty;
        defer exceptions.deinit(allocator);

        if (chunk_size >= format.wii_group_size) {
            const local_chunk = entry_relative_raw / chunk_size;
            const first_sector = local_chunk * sectors_per_chunk;
            const sectors = @min(
                sectors_per_chunk,
                entry.sector_count - first_sector,
            );
            const expected_main = sectors * wii.block_data_size;
            const list_count = chunk_size / format.wii_group_size;
            const local_decrypted_offset = std.math.mul(
                usize,
                local_chunk,
                decrypted_per_chunk,
            ) catch return error.IntegerOverflow;
            const decrypted_offset = std.math.add(
                usize,
                entry_decrypted_offset,
                local_decrypted_offset,
            ) catch return error.IntegerOverflow;
            var chunk = try self.decodePartitionChunkAlloc(
                allocator,
                entry.group_index + local_chunk,
                expected_main,
                list_count,
                decrypted_offset,
            );
            defer chunk.deinit();
            const group_in_chunk = (entry_relative_raw % chunk_size) /
                format.wii_group_size;
            const data_start = group_in_chunk * wii.group_data_size;
            if (data_start > chunk.data.len) return error.InvalidWia;
            const data_len = @min(
                wii.group_data_size,
                chunk.data.len - data_start,
            );
            @memcpy(decrypted_group[0..data_len], chunk.data[data_start..][0..data_len]);
            try exceptions.appendSlice(
                allocator,
                chunk.exceptions.list(group_in_chunk),
            );
        } else {
            const chunks_per_group = format.wii_group_size / chunk_size;
            const first_local_chunk = entry_relative_raw / chunk_size;
            for (0..chunks_per_group) |subchunk| {
                const local_chunk = first_local_chunk + subchunk;
                const first_sector = local_chunk * sectors_per_chunk;
                if (first_sector >= entry.sector_count) break;
                const sectors = @min(
                    sectors_per_chunk,
                    entry.sector_count - first_sector,
                );
                const expected_main = sectors * wii.block_data_size;
                const local_decrypted_offset = std.math.mul(
                    usize,
                    local_chunk,
                    decrypted_per_chunk,
                ) catch return error.IntegerOverflow;
                const decrypted_offset = std.math.add(
                    usize,
                    entry_decrypted_offset,
                    local_decrypted_offset,
                ) catch return error.IntegerOverflow;
                var chunk = try self.decodePartitionChunkAlloc(
                    allocator,
                    entry.group_index + local_chunk,
                    expected_main,
                    1,
                    decrypted_offset,
                );
                defer chunk.deinit();
                const destination = subchunk * decrypted_per_chunk;
                @memcpy(
                    decrypted_group[destination..][0..chunk.data.len],
                    chunk.data,
                );
                const additional_offset = subchunk * sectors_per_chunk *
                    wii.block_header_size;
                for (chunk.exceptions.list(0)) |exception| {
                    const adjusted = std.math.add(
                        usize,
                        exception.offset,
                        additional_offset,
                    ) catch return error.IntegerOverflow;
                    if (adjusted > std.math.maxInt(u16))
                        return error.CorruptFrame;
                    try exceptions.append(allocator, .{
                        .offset = @intCast(adjusted),
                        .hash = exception.hash,
                    });
                }
            }
        }
        return wii.reconstructEncryptedGroupAlloc(
            allocator,
            decrypted_group,
            &partition.key,
            exceptions.items,
        );
    }

    fn decodePartitionChunkAlloc(
        self: Archive,
        allocator: std.mem.Allocator,
        group_index: usize,
        expected_main_size: usize,
        exception_list_count: usize,
        data_offset: usize,
    ) Error!DecodedPartitionChunk {
        if (group_index >= self.groups.len) return error.InvalidWia;
        const group = self.groups[group_index];
        if (group.stored_size == 0) {
            const data = try allocator.alloc(u8, expected_main_size);
            errdefer allocator.free(data);
            @memset(data, 0);
            const starts = try allocator.alloc(usize, exception_list_count + 1);
            errdefer allocator.free(starts);
            @memset(starts, 0);
            return .{
                .allocator = allocator,
                .data = data,
                .exceptions = .{
                    .allocator = allocator,
                    .entries = try allocator.alloc(format.HashException, 0),
                    .list_starts = starts,
                    .consumed = 0,
                },
            };
        }
        const stored_offset = std.math.cast(usize, group.data_offset) orelse
            return error.IntegerOverflow;
        const stored = self.bytes[stored_offset..][0..group.stored_size];
        const compression = if (self.header1.container == .rvz and
            !group.compressed)
            format.Compression.none
        else
            self.header2.compression;
        const compressed_exceptions = @intFromEnum(compression) >
            @intFromEnum(format.Compression.purge);
        const primary_size = if (group.rvz_packed_size == 0)
            expected_main_size
        else
            group.rvz_packed_size;
        var exceptions: wii.ParsedExceptionLists = undefined;
        var primary: []u8 = undefined;
        if (compressed_exceptions) {
            const per_list = std.math.add(
                usize,
                2,
                std.math.mul(
                    usize,
                    self.max_hash_exceptions_per_list,
                    22,
                ) catch return error.IntegerOverflow,
            ) catch return error.IntegerOverflow;
            const exception_limit = std.math.mul(
                usize,
                exception_list_count,
                per_list,
            ) catch return error.IntegerOverflow;
            const output_limit = std.math.add(
                usize,
                primary_size,
                exception_limit,
            ) catch return error.IntegerOverflow;
            const combined = try codec.decodeAllocLimited(
                allocator,
                stored,
                compression,
                self.header2.compressor_data[0..self.header2.compressor_data_len],
                output_limit,
                self.max_dictionary_size,
            );
            defer allocator.free(combined);
            exceptions = try wii.parseExceptionListsAlloc(
                allocator,
                combined,
                exception_list_count,
                false,
                self.max_hash_exceptions_per_list,
            );
            errdefer exceptions.deinit();
            if (combined.len - exceptions.consumed != primary_size)
                return error.SizeMismatch;
            primary = try allocator.dupe(u8, combined[exceptions.consumed..]);
        } else {
            exceptions = try wii.parseExceptionListsAlloc(
                allocator,
                stored,
                exception_list_count,
                true,
                self.max_hash_exceptions_per_list,
            );
            errdefer exceptions.deinit();
            const main_stored = stored[exceptions.consumed..];
            primary = if (compression == .purge)
                try codec.decodePurgeWithHashPrefixAlloc(
                    allocator,
                    main_stored,
                    primary_size,
                    stored[0..exceptions.consumed],
                )
            else
                try codec.decodeAllocExact(
                    allocator,
                    main_stored,
                    compression,
                    self.header2.compressor_data[0..self.header2.compressor_data_len],
                    primary_size,
                    self.max_dictionary_size,
                );
        }
        const data = if (group.rvz_packed_size == 0)
            primary
        else blk: {
            defer allocator.free(primary);
            break :blk try rvz_pack.decodeAllocExact(
                allocator,
                primary,
                expected_main_size,
                data_offset,
            );
        };
        return .{
            .allocator = allocator,
            .data = data,
            .exceptions = exceptions,
        };
    }

    fn findDataRange(self: Archive, offset: usize) ?DataRange {
        var low: usize = 0;
        var high = self.data_ranges.len;
        while (low < high) {
            const mid = low + (high - low) / 2;
            const range = self.data_ranges[mid];
            if (offset < range.start) {
                high = mid;
            } else if (offset >= range.end) {
                low = mid + 1;
            } else {
                return range;
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

fn dataRangeLessThan(_: void, lhs: DataRange, rhs: DataRange) bool {
    return lhs.start < rhs.start;
}
