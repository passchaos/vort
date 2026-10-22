const std = @import("std");
const types = @import("types.zig");
const format = @import("../format.zig");

pub const Error = types.Error || std.mem.Allocator.Error;

/// Takes ownership of bytes on success; failures leave it with the caller.
pub fn parseOwned(allocator: std.mem.Allocator, bytes: []u8, block_size: usize) Error!types.Directory {
    if (block_size == 0) return error.InvalidErofs;
    var entries: std.ArrayList(types.DirectoryEntry) = .empty;
    errdefer entries.deinit(allocator);
    var block_start: usize = 0;
    var previous_name: ?[]const u8 = null;
    while (block_start < bytes.len) {
        const block_len = @min(block_size, bytes.len - block_start);
        const block = bytes[block_start..][0..block_len];
        if (block.len < 12) return error.InvalidErofs;
        const first_name_offset: usize = format.readU16(block, 8);
        if (first_name_offset < 12 or first_name_offset > block.len or first_name_offset % 12 != 0) return error.InvalidErofs;
        const count = first_name_offset / 12;
        for (0..count) |index| {
            const entry_offset = index * 12;
            const name_start: usize = format.readU16(block, entry_offset + 8);
            if (name_start < first_name_offset or name_start >= block.len) return error.InvalidErofs;
            const name_end = if (index + 1 < count) @as(usize, format.readU16(block, entry_offset + 20)) else blk: {
                const tail = block[name_start..];
                break :blk name_start + (std.mem.indexOfScalar(u8, tail, 0) orelse tail.len);
            };
            if (name_end <= name_start or name_end > block.len or name_end - name_start > format.name_max) return error.InvalidErofs;
            const name = block[name_start..name_end];
            if (std.mem.indexOfScalar(u8, name, '/') != null or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidErofs;
            const file_type = std.enums.fromInt(format.FileType, block[entry_offset + 10]) orelse return error.InvalidErofs;
            if (!std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..")) {
                if (previous_name) |previous| if (std.mem.order(u8, previous, name) != .lt) return error.InvalidErofs;
                previous_name = name;
                try entries.append(allocator, .{ .nid = format.readU64(block, entry_offset), .name = name, .file_type = file_type });
            }
        }
        block_start += block_len;
    }
    return .{ .allocator = allocator, .bytes = bytes, .entries = try entries.toOwnedSlice(allocator) };
}

pub fn validName(name: []const u8) bool {
    return name.len != 0 and !std.mem.eql(u8, name, ".") and !std.mem.eql(u8, name, "..") and std.mem.indexOfScalar(u8, name, '/') == null and std.mem.indexOfScalar(u8, name, 0) == null;
}

test "EROFS directory parsing rejects embedded NUL names and invalid block sizes" {
    var bytes: [32]u8 = @splat(0);
    std.mem.writeInt(u16, bytes[8..10], 24, .little);
    std.mem.writeInt(u16, bytes[20..22], 27, .little);
    bytes[10] = 1;
    bytes[22] = 1;
    @memcpy(bytes[24..27], "a\x00b");
    @memcpy(bytes[27..30], "def");
    try std.testing.expectError(error.InvalidErofs, parseOwned(std.testing.allocator, &bytes, 32));
    try std.testing.expectError(error.InvalidErofs, parseOwned(std.testing.allocator, &bytes, 0));
}
