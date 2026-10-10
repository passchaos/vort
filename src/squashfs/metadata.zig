const std = @import("std");
const core = @import("../core.zig");
const codec = @import("codec.zig");
const format = @import("format.zig");

pub const Error = core.Error || codec.Error || std.mem.Allocator.Error ||
    error{InvalidSquashfs};

pub const Block = struct {
    relative_offset: usize,
    decoded_offset: usize,
    decoded_size: usize,
};

pub const Table = struct {
    allocator: std.mem.Allocator,
    bytes: []u8,
    blocks: []Block,

    pub fn deinit(self: *Table) void {
        self.allocator.free(self.blocks);
        self.allocator.free(self.bytes);
        self.* = undefined;
    }

    pub fn resolve(self: Table, block: usize, offset: usize) Error!usize {
        if (offset >= format.metadata_size) return error.InvalidSquashfs;
        for (self.blocks) |entry| {
            if (entry.relative_offset == block) {
                if (offset >= entry.decoded_size) return error.InvalidSquashfs;
                return std.math.add(usize, entry.decoded_offset, offset) catch
                    return error.IntegerOverflow;
            }
        }
        return error.InvalidSquashfs;
    }

    pub fn slice(self: Table, block: usize, offset: usize, length: usize) Error![]const u8 {
        const start = try self.resolve(block, offset);
        const end = std.math.add(usize, start, length) catch return error.IntegerOverflow;
        if (end > self.bytes.len) return error.TruncatedFrame;
        return self.bytes[start..end];
    }
};

pub fn load(
    allocator: std.mem.Allocator,
    input: []const u8,
    superblock: format.Superblock,
    start: usize,
    end: usize,
) Error!Table {
    if (start > end or end > superblock.bytes_used) return error.InvalidSquashfs;
    var decoded: std.ArrayList(u8) = .empty;
    errdefer decoded.deinit(allocator);
    var blocks: std.ArrayList(Block) = .empty;
    errdefer blocks.deinit(allocator);
    var position = start;
    while (position < end) {
        if (end - position < 2) return error.TruncatedFrame;
        const relative_offset = position - start;
        const size_field = format.readU16(input, position);
        const compressed = size_field & 0x8000 == 0;
        const stored_size: usize = size_field & 0x7fff;
        if (stored_size == 0 or stored_size > format.metadata_size)
            return error.InvalidSquashfs;
        const header_size: usize = if (superblock.flags.checkData()) 3 else 2;
        const payload_start = std.math.add(usize, position, header_size) catch
            return error.IntegerOverflow;
        const next = std.math.add(usize, payload_start, stored_size) catch
            return error.IntegerOverflow;
        if (next > end) return error.TruncatedFrame;
        if (superblock.flags.checkData() and input[position + 2] != 0xff)
            return error.InvalidSquashfs;
        const decoded_offset = decoded.items.len;
        if (compressed) {
            const bytes = try codec.decodeAllocLimited(
                allocator,
                superblock.compression,
                input[payload_start..next],
                format.metadata_size,
            );
            defer allocator.free(bytes);
            if (bytes.len == 0 or (next < end and bytes.len != format.metadata_size))
                return error.SizeMismatch;
            try decoded.appendSlice(allocator, bytes);
        } else {
            if (next < end and stored_size != format.metadata_size)
                return error.SizeMismatch;
            try decoded.appendSlice(allocator, input[payload_start..next]);
        }
        try blocks.append(allocator, .{
            .relative_offset = relative_offset,
            .decoded_offset = decoded_offset,
            .decoded_size = decoded.items.len - decoded_offset,
        });
        position = next;
    }
    return .{
        .allocator = allocator,
        .bytes = try decoded.toOwnedSlice(allocator),
        .blocks = try blocks.toOwnedSlice(allocator),
    };
}

pub fn decodeBlockAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    superblock: format.Superblock,
    position: usize,
) Error![]u8 {
    const decoded = try decodeBlockAt(allocator, input, superblock, position);
    return decoded.bytes;
}

pub const DecodedBlock = struct {
    bytes: []u8,
    next_position: usize,
};

pub fn decodeBlockAt(
    allocator: std.mem.Allocator,
    input: []const u8,
    superblock: format.Superblock,
    position: usize,
) Error!DecodedBlock {
    if (input.len -| position < 2) return error.TruncatedFrame;
    const size_field = format.readU16(input, position);
    const compressed = size_field & 0x8000 == 0;
    const stored_size: usize = size_field & 0x7fff;
    if (stored_size == 0 or stored_size > format.metadata_size)
        return error.InvalidSquashfs;
    const header_size: usize = if (superblock.flags.checkData()) 3 else 2;
    const payload_start = std.math.add(usize, position, header_size) catch
        return error.IntegerOverflow;
    const payload_end = std.math.add(usize, payload_start, stored_size) catch
        return error.IntegerOverflow;
    if (payload_end > superblock.bytes_used) return error.TruncatedFrame;
    const bytes = if (!compressed)
        try allocator.dupe(u8, input[payload_start..payload_end])
    else
        try codec.decodeAllocLimited(
            allocator,
            superblock.compression,
            input[payload_start..payload_end],
            format.metadata_size,
        );
    return .{ .bytes = bytes, .next_position = payload_end };
}

pub fn readReferenceAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    superblock: format.Superblock,
    table_start: usize,
    block: usize,
    offset: usize,
    length: usize,
) Error![]u8 {
    if (offset >= format.metadata_size) return error.InvalidSquashfs;
    const absolute = std.math.add(usize, table_start, block) catch
        return error.IntegerOverflow;
    if (absolute >= superblock.bytes_used) return error.InvalidSquashfs;
    const output = try allocator.alloc(u8, length);
    errdefer allocator.free(output);
    var output_offset: usize = 0;
    var position = absolute;
    var block_offset = offset;
    while (output_offset < length) {
        const decoded = try decodeBlockAt(allocator, input, superblock, position);
        defer allocator.free(decoded.bytes);
        if (block_offset >= decoded.bytes.len) return error.InvalidSquashfs;
        const take = @min(decoded.bytes.len - block_offset, length - output_offset);
        @memcpy(output[output_offset..][0..take], decoded.bytes[block_offset..][0..take]);
        output_offset += take;
        position = decoded.next_position;
        block_offset = 0;
    }
    return output;
}
