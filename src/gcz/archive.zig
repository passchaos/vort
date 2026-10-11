const std = @import("std");
const checksum = @import("../checksum.zig");
const deflate = @import("../deflate.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || std.mem.Allocator.Error;

pub const OpenOptions = struct {
    verify_hashes: bool = true,
    max_blocks: usize = 1 << 24,
    max_block_size: usize = 64 * 1024 * 1024,
    max_compressed_block_bytes: usize = 64 * 1024 * 1024 + 64,
};

pub const Block = struct {
    index: usize,
    offset: usize,
    stored_size: usize,
    raw: bool,
    hash: u32,
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,
    pointers_offset: usize,
    hashes_offset: usize,
    data_offset: usize,
    verify_hashes: bool,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.block_count > options.max_blocks or
            header.block_size > options.max_block_size)
            return error.OutputLimitExceeded;
        if (header.logical_size > std.math.maxInt(usize))
            return error.OutputLimitExceeded;
        const pointers_bytes = std.math.mul(
            usize,
            header.block_count,
            format.pointer_entry_size,
        ) catch return error.IntegerOverflow;
        const hashes_bytes = std.math.mul(
            usize,
            header.block_count,
            format.hash_entry_size,
        ) catch return error.IntegerOverflow;
        const hashes_offset = std.math.add(
            usize,
            format.header_size,
            pointers_bytes,
        ) catch return error.IntegerOverflow;
        const data_offset = std.math.add(
            usize,
            hashes_offset,
            hashes_bytes,
        ) catch return error.IntegerOverflow;
        if (data_offset > input.len) return error.TruncatedFrame;
        const data_end_u64 = std.math.add(
            u64,
            data_offset,
            header.compressed_data_size,
        ) catch return error.IntegerOverflow;
        if (data_end_u64 > input.len) return error.TruncatedFrame;

        const archive: Archive = .{
            .bytes = input,
            .header = header,
            .pointers_offset = format.header_size,
            .hashes_offset = hashes_offset,
            .data_offset = data_offset,
            .verify_hashes = options.verify_hashes,
        };
        var previous_offset: u64 = 0;
        for (0..header.block_count) |block_index| {
            const raw_pointer = archive.rawPointer(block_index);
            const relative_offset = raw_pointer & format.offset_mask;
            if (block_index == 0) {
                if (relative_offset != 0) return error.InvalidGcz;
            } else if (relative_offset < previous_offset) {
                return error.InvalidGcz;
            }
            previous_offset = relative_offset;
            const block_info = try archive.block(block_index);
            if (block_info.stored_size == 0) return error.InvalidGcz;
            if (block_info.raw) {
                if (block_info.stored_size != header.block_size)
                    return error.InvalidGcz;
            } else {
                const dolphin_limit = std.math.add(
                    usize,
                    header.block_size,
                    64,
                ) catch return error.IntegerOverflow;
                if (block_info.stored_size > dolphin_limit or
                    block_info.stored_size > options.max_compressed_block_bytes)
                    return error.OutputLimitExceeded;
            }
        }
        return archive;
    }

    pub fn block(self: Archive, block_index: usize) Error!Block {
        if (block_index >= self.header.block_count)
            return error.RangeOutOfBounds;
        const raw_pointer = self.rawPointer(block_index);
        const relative_u64 = raw_pointer & format.offset_mask;
        const next_u64 = if (block_index + 1 < self.header.block_count)
            self.rawPointer(block_index + 1) & format.offset_mask
        else
            self.header.compressed_data_size;
        if (next_u64 < relative_u64 or
            next_u64 > self.header.compressed_data_size)
            return error.InvalidGcz;
        const relative = std.math.cast(usize, relative_u64) orelse
            return error.IntegerOverflow;
        const stored_size = std.math.cast(usize, next_u64 - relative_u64) orelse
            return error.IntegerOverflow;
        const offset = std.math.add(usize, self.data_offset, relative) catch
            return error.IntegerOverflow;
        const end = std.math.add(usize, offset, stored_size) catch
            return error.IntegerOverflow;
        if (end > self.bytes.len) return error.TruncatedFrame;
        return .{
            .index = block_index,
            .offset = offset,
            .stored_size = stored_size,
            .raw = raw_pointer & format.raw_flag != 0,
            .hash = format.readU32Le(
                self.bytes,
                self.hashes_offset + block_index * format.hash_entry_size,
            ),
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size: usize = @intCast(self.header.logical_size);
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
        if (end > self.header.logical_size) return error.RangeOutOfBounds;
        if (output.len == 0) return;
        const scratch = try allocator.alloc(u8, self.header.block_size);
        defer allocator.free(scratch);
        var position = offset;
        var written: usize = 0;
        while (written < output.len) {
            const block_index = position / self.header.block_size;
            const within_block = position % self.header.block_size;
            const logical_len = self.logicalBlockLen(block_index);
            const copy_len = @min(
                output.len - written,
                logical_len - within_block,
            );
            const block_info = try self.block(block_index);
            const payload = self.bytes[block_info.offset..][0..block_info.stored_size];
            if (self.verify_hashes and checksum.adler32(payload) != block_info.hash)
                return error.ChecksumMismatch;
            if (block_info.raw) {
                @memcpy(scratch, payload);
            } else {
                const decoded_len = try deflate.decodeZlib(payload, scratch);
                if (decoded_len != self.header.block_size)
                    return error.SizeMismatch;
            }
            @memcpy(
                output[written..][0..copy_len],
                scratch[within_block..][0..copy_len],
            );
            position += copy_len;
            written += copy_len;
        }
    }

    fn logicalBlockLen(self: Archive, block_index: usize) usize {
        const size: usize = @intCast(self.header.logical_size);
        const start = block_index * @as(usize, self.header.block_size);
        return @min(@as(usize, self.header.block_size), size - start);
    }

    fn rawPointer(self: Archive, block_index: usize) u64 {
        return format.readU64Le(
            self.bytes,
            self.pointers_offset + block_index * format.pointer_entry_size,
        );
    }
};
