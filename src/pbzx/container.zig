const std = @import("std");
const xz = @import("../xz.zig");
const format = @import("format.zig");

pub const Error = format.Error || xz.Error || std.mem.Allocator.Error;

pub const ParseOptions = struct {
    max_output_len: usize = std.math.maxInt(usize),
    max_chunk_decoded_bytes: usize = 64 * 1024 * 1024,
    max_chunks: usize = 1 << 20,
    max_xz_dictionary_bytes: usize = 256 * 1024 * 1024,
};

pub const Iterator = struct {
    bytes: []const u8,
    chunk_size: usize,
    position: usize = format.header_size,
    decoded_position: usize = 0,
    index: usize = 0,
    ended: bool = false,

    pub fn next(self: *Iterator) Error!?format.Chunk {
        if (self.ended or self.position == self.bytes.len) return null;
        if (self.bytes.len - self.position < format.chunk_header_size)
            return error.TruncatedFrame;
        const decoded_size_u64 = std.mem.readInt(
            u64,
            self.bytes[self.position..][0..8],
            .big,
        );
        const packed_size_u64 = std.mem.readInt(
            u64,
            self.bytes[self.position + 8 ..][0..8],
            .big,
        );
        self.position += format.chunk_header_size;
        if (decoded_size_u64 == 0 and packed_size_u64 == 0) {
            if (self.position != self.bytes.len) return error.InvalidPbzx;
            self.ended = true;
            return null;
        }
        if (decoded_size_u64 == 0 or packed_size_u64 == 0)
            return error.InvalidPbzx;
        const decoded_size = std.math.cast(usize, decoded_size_u64) orelse
            return error.IntegerOverflow;
        const packed_size = std.math.cast(usize, packed_size_u64) orelse
            return error.IntegerOverflow;
        if (decoded_size > self.chunk_size) return error.InvalidPbzx;
        const packed_end = std.math.add(usize, self.position, packed_size) catch
            return error.IntegerOverflow;
        if (packed_end > self.bytes.len) return error.TruncatedFrame;
        if (packed_size != decoded_size and
            (packed_size < format.xz_magic.len or
                !std.mem.eql(
                    u8,
                    self.bytes[self.position..][0..format.xz_magic.len],
                    &format.xz_magic,
                )))
            return error.UnsupportedPbzxCompression;
        const chunk = format.Chunk{
            .index = self.index,
            .decoded_offset = self.decoded_position,
            .decoded_size = decoded_size,
            .packed_offset = self.position,
            .packed_size = packed_size,
        };
        self.position = packed_end;
        self.decoded_position = std.math.add(
            usize,
            self.decoded_position,
            decoded_size,
        ) catch return error.IntegerOverflow;
        self.index = std.math.add(usize, self.index, 1) catch
            return error.IntegerOverflow;
        return chunk;
    }
};

pub const Archive = struct {
    bytes: []const u8,
    chunk_size: usize,
    chunk_count: usize,
    decoded_size: usize,
    max_xz_dictionary_bytes: usize,

    pub fn init(input: []const u8) Error!Archive {
        return initWithOptions(input, .{});
    }

    pub fn initWithOptions(input: []const u8, options: ParseOptions) Error!Archive {
        if (input.len < format.header_size) return error.TruncatedFrame;
        if (!std.mem.eql(u8, input[0..4], format.magic)) return error.InvalidMagic;
        const chunk_size_u64 = std.mem.readInt(u64, input[4..12], .big);
        const chunk_size = std.math.cast(usize, chunk_size_u64) orelse
            return error.IntegerOverflow;
        if (chunk_size == 0) return error.InvalidPbzx;
        if (chunk_size > options.max_chunk_decoded_bytes)
            return error.OutputLimitExceeded;
        var iterator_value = Iterator{ .bytes = input, .chunk_size = chunk_size };
        var count: usize = 0;
        var decoded_size: usize = 0;
        while (try iterator_value.next()) |chunk| {
            count = std.math.add(usize, count, 1) catch
                return error.IntegerOverflow;
            if (count > options.max_chunks) return error.OutputLimitExceeded;
            decoded_size = std.math.add(
                usize,
                decoded_size,
                chunk.decoded_size,
            ) catch return error.IntegerOverflow;
            if (decoded_size > options.max_output_len)
                return error.OutputLimitExceeded;
        }
        if (iterator_value.position != input.len) return error.TrailingData;
        return .{
            .bytes = input,
            .chunk_size = chunk_size,
            .chunk_count = count,
            .decoded_size = decoded_size,
            .max_xz_dictionary_bytes = options.max_xz_dictionary_bytes,
        };
    }

    pub fn iterator(self: Archive) Iterator {
        return .{ .bytes = self.bytes, .chunk_size = self.chunk_size };
    }

    pub fn decodeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        max_output_len: usize,
    ) Error![]u8 {
        if (self.decoded_size > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, self.decoded_size);
        errdefer allocator.free(output);
        try self.decodeRangeInto(allocator, 0, output);
        return output;
    }

    pub fn decodeRangeAllocLimited(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        length: usize,
        max_output_len: usize,
    ) Error![]u8 {
        if (length > max_output_len) return error.OutputLimitExceeded;
        const output = try allocator.alloc(u8, length);
        errdefer allocator.free(output);
        try self.decodeRangeInto(allocator, offset, output);
        return output;
    }

    pub fn decodeRangeInto(
        self: Archive,
        allocator: std.mem.Allocator,
        offset: usize,
        output: []u8,
    ) Error!void {
        const range_end = std.math.add(usize, offset, output.len) catch
            return error.IntegerOverflow;
        if (range_end > self.decoded_size) return error.RangeOutOfBounds;
        if (output.len == 0) return;
        var iterator_value = self.iterator();
        var copied: usize = 0;
        while (try iterator_value.next()) |chunk| {
            const chunk_end = chunk.decoded_offset + chunk.decoded_size;
            if (chunk_end <= offset or chunk.decoded_offset >= range_end) continue;
            const copy_start = @max(offset, chunk.decoded_offset);
            const copy_end = @min(range_end, chunk_end);
            const copy_len = copy_end - copy_start;
            const packed_bytes = self.bytes[chunk.packed_offset..][0..chunk.packed_size];
            if (chunk.isStored()) {
                @memcpy(
                    output[copy_start - offset ..][0..copy_len],
                    packed_bytes[copy_start - chunk.decoded_offset ..][0..copy_len],
                );
            } else {
                const decoded = try xz.decodeAllocWithLimits(
                    allocator,
                    packed_bytes,
                    chunk.decoded_size,
                    self.max_xz_dictionary_bytes,
                );
                defer allocator.free(decoded);
                if (decoded.len != chunk.decoded_size) return error.SizeMismatch;
                @memcpy(
                    output[copy_start - offset ..][0..copy_len],
                    decoded[copy_start - chunk.decoded_offset ..][0..copy_len],
                );
            }
            copied += copy_len;
        }
        if (copied != output.len) return error.InvalidPbzx;
    }
};
