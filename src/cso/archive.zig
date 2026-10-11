const std = @import("std");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const format = @import("format.zig");

pub const Error = format.Error || deflate.Error || lz4.Error ||
    std.mem.Allocator.Error;

pub const OpenOptions = struct {
    max_blocks: usize = 1 << 24,
    max_block_size: usize = format.maximum_block_size,
    max_compressed_block_bytes: usize = 2 * format.maximum_block_size,
};

pub const Block = struct {
    index: usize,
    offset: usize,
    stored_span: usize,
    codec: format.Codec,
};

pub const Archive = struct {
    bytes: []const u8,
    header: format.Header,
    index_offset: usize,

    pub fn init(input: []const u8, options: OpenOptions) Error!Archive {
        const header = try format.parseHeader(input);
        if (header.block_count > options.max_blocks or
            header.block_size > options.max_block_size)
            return error.OutputLimitExceeded;
        if (header.uncompressed_size > std.math.maxInt(usize))
            return error.OutputLimitExceeded;
        const index_entries = std.math.add(
            usize,
            header.block_count,
            1,
        ) catch return error.IntegerOverflow;
        const index_bytes = std.math.mul(usize, index_entries, 4) catch
            return error.IntegerOverflow;
        const index_end = std.math.add(
            usize,
            header.header_bytes,
            index_bytes,
        ) catch return error.IntegerOverflow;
        if (index_end > input.len) return error.TruncatedFrame;

        var previous: u64 = 0;
        for (0..index_entries) |entry_index| {
            const raw = format.readU32Le(
                input,
                header.header_bytes + entry_index * 4,
            );
            const offset = try format.physicalOffset(raw, header.index_shift);
            if (entry_index == 0) {
                if (offset < index_end) return error.InvalidCso;
            } else if (offset < previous) {
                return error.InvalidCso;
            }
            if (offset > input.len) return error.TruncatedFrame;
            if (offset % header.alignment() != 0) return error.InvalidCso;
            previous = offset;
        }

        var archive: Archive = .{
            .bytes = input,
            .header = header,
            .index_offset = header.header_bytes,
        };
        if (header.format == .cso2 and
            archive.rawIndex(header.block_count) & format.raw_flag != 0)
            return error.InvalidCso;
        for (0..header.block_count) |block_index| {
            const block_info = try archive.block(block_index);
            if (block_info.stored_span == 0) return error.InvalidCso;
            switch (block_info.codec) {
                .raw => {
                    const logical_len = archive.logicalBlockLen(block_index);
                    if (block_info.stored_span < logical_len)
                        return error.TruncatedFrame;
                    const maximum_span = std.math.add(
                        usize,
                        header.block_size,
                        @as(usize, @intCast(header.alignment() - 1)),
                    ) catch return error.IntegerOverflow;
                    if (block_info.stored_span > maximum_span)
                        return error.InvalidCso;
                },
                .deflate, .lz4 => if (block_info.stored_span >
                    options.max_compressed_block_bytes)
                    return error.OutputLimitExceeded,
            }
        }
        return archive;
    }

    pub fn block(self: Archive, block_index: usize) Error!Block {
        if (block_index >= self.header.block_count)
            return error.RangeOutOfBounds;
        const raw = self.rawIndex(block_index);
        const next_raw = self.rawIndex(block_index + 1);
        const offset_u64 = try format.physicalOffset(raw, self.header.index_shift);
        const next_u64 = try format.physicalOffset(
            next_raw,
            self.header.index_shift,
        );
        if (next_u64 < offset_u64) return error.InvalidCso;
        const offset = std.math.cast(usize, offset_u64) orelse
            return error.IntegerOverflow;
        const next = std.math.cast(usize, next_u64) orelse
            return error.IntegerOverflow;
        if (next > self.bytes.len) return error.TruncatedFrame;
        return .{
            .index = block_index,
            .offset = offset,
            .stored_span = next - offset,
            .codec = format.codecForIndex(
                self.header.format,
                raw,
                next_u64 - offset_u64,
                self.header.block_size,
            ),
        };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        const size = std.math.cast(usize, self.header.uncompressed_size) orelse
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
        if (end > self.header.uncompressed_size)
            return error.RangeOutOfBounds;
        if (output.len == 0) return;
        const scratch = try allocator.alloc(u8, self.header.block_size);
        defer allocator.free(scratch);
        var logical_offset = offset;
        var written: usize = 0;
        while (written < output.len) {
            const block_index = logical_offset / self.header.block_size;
            const within_block = logical_offset % self.header.block_size;
            const logical_block_len = self.logicalBlockLen(block_index);
            const copy_len = @min(
                output.len - written,
                logical_block_len - within_block,
            );
            const block_info = try self.block(block_index);
            const payload = self.bytes[block_info.offset..][0..block_info.stored_span];
            switch (block_info.codec) {
                .raw => @memcpy(
                    scratch[0..logical_block_len],
                    payload[0..logical_block_len],
                ),
                .deflate => try self.decodeDeflateBlock(
                    payload,
                    scratch,
                    logical_block_len,
                ),
                .lz4 => try self.decodeLz4Block(
                    payload,
                    scratch,
                    logical_block_len,
                ),
            }
            @memcpy(
                output[written..][0..copy_len],
                scratch[within_block..][0..copy_len],
            );
            logical_offset += copy_len;
            written += copy_len;
        }
    }

    fn decodeDeflateBlock(
        self: Archive,
        payload: []const u8,
        scratch: []u8,
        logical_block_len: usize,
    ) Error!void {
        const decoded = try deflate.decodeRawAuto(payload, scratch);
        if (decoded.output_written != self.header.block_size and
            decoded.output_written != logical_block_len)
            return error.SizeMismatch;
        try self.validatePadding(payload[decoded.input_read..]);
    }

    fn decodeLz4Block(
        self: Archive,
        payload: []const u8,
        scratch: []u8,
        logical_block_len: usize,
    ) Error!void {
        const maximum_padding = @min(
            payload.len - 1,
            @as(usize, @intCast(self.header.alignment() - 1)),
        );
        var padding_len: usize = 0;
        while (padding_len <= maximum_padding) : (padding_len += 1) {
            const encoded = payload[0 .. payload.len - padding_len];
            const written = lz4.decodeBlockIntoSlice(
                encoded,
                scratch,
                null,
            ) catch continue;
            if (written == self.header.block_size or
                written == logical_block_len)
                return;
        }
        return error.CorruptFrame;
    }

    fn validatePadding(self: Archive, padding: []const u8) Error!void {
        if (padding.len >= self.header.alignment()) return error.TrailingData;
    }

    fn logicalBlockLen(self: Archive, block_index: usize) usize {
        const size: usize = @intCast(self.header.uncompressed_size);
        const start = block_index * @as(usize, self.header.block_size);
        return @min(@as(usize, self.header.block_size), size - start);
    }

    fn rawIndex(self: Archive, entry_index: usize) u32 {
        return format.readU32Le(
            self.bytes,
            self.index_offset + entry_index * 4,
        );
    }
};
