const std = @import("std");
const types = @import("types.zig");
const format = @import("../format.zig");

pub const Error = types.Error || std.mem.Allocator.Error;

pub const Validator = struct {
    previous: [format.name_max]u8 = undefined,
    previous_size: ?usize = null,

    fn accept(self: *Validator, name: []const u8) Error!void {
        if (self.previous_size) |size| if (std.mem.order(u8, self.previous[0..size], name) != .lt) return error.InvalidErofs;
        @memcpy(self.previous[0..name.len], name);
        self.previous_size = name.len;
    }
};

/// Returned names borrow bytes. The validator copies its cross-block key.
pub const Block = struct {
    bytes: []const u8,
    names_start: usize,
    count: usize,
    index: usize = 0,
    attempt_offset: usize = 0,

    pub fn init(bytes: []const u8) Error!Block {
        if (bytes.len < 12) return error.InvalidErofs;
        const names: usize = format.readU16(bytes, 8);
        if (names < 12 or names > bytes.len or names % 12 != 0) return error.InvalidErofs;
        return .{ .bytes = bytes, .names_start = names, .count = names / 12 };
    }

    pub fn next(self: *Block, validator: *Validator) Error!?types.DirectoryEntry {
        while (self.index < self.count) {
            const index = self.index;
            const offset = index * 12;
            self.attempt_offset = offset;
            const start: usize = format.readU16(self.bytes, offset + 8);
            if (start < self.names_start or start >= self.bytes.len) return error.InvalidErofs;
            const end = if (index + 1 < self.count) @as(usize, format.readU16(self.bytes, offset + 20)) else data: {
                const tail = self.bytes[start..];
                break :data start + (std.mem.indexOfScalar(u8, tail, 0) orelse tail.len);
            };
            if (end <= start or end > self.bytes.len or end - start > format.name_max) return error.InvalidErofs;
            const name = self.bytes[start..end];
            if (std.mem.indexOfScalar(u8, name, '/') != null or std.mem.indexOfScalar(u8, name, 0) != null) return error.InvalidErofs;
            const file_type = std.enums.fromInt(format.FileType, self.bytes[offset + 10]) orelse return error.InvalidErofs;
            self.index += 1;
            if (std.mem.eql(u8, name, ".") or std.mem.eql(u8, name, "..")) continue;
            try validator.accept(name);
            return .{ .nid = format.readU64(self.bytes, offset), .name = name, .file_type = file_type };
        }
        return null;
    }
};

/// Takes ownership of bytes on success; failures leave it with the caller.
pub fn parseOwned(allocator: std.mem.Allocator, bytes: []u8, block_size: usize) Error!types.Directory {
    if (block_size == 0) return error.InvalidErofs;
    var entries: std.ArrayList(types.DirectoryEntry) = .empty;
    errdefer entries.deinit(allocator);
    var validator = Validator{};
    var start: usize = 0;
    while (start < bytes.len) {
        const size = @min(block_size, bytes.len - start);
        var block = try Block.init(bytes[start..][0..size]);
        while (try block.next(&validator)) |entry| try entries.append(allocator, entry);
        start += size;
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

test "EROFS directory validator retains ordering across reused block storage" {
    var bytes: [16]u8 = @splat(0);
    std.mem.writeInt(u16, bytes[8..10], 12, .little);
    bytes[10] = 1;
    @memcpy(bytes[12..15], "cat");
    var validator = Validator{};
    var first = try Block.init(&bytes);
    try std.testing.expectEqualStrings("cat", (try first.next(&validator)).?.name);
    @memcpy(bytes[12..15], "dog");
    var second = try Block.init(&bytes);
    try std.testing.expectEqualStrings("dog", (try second.next(&validator)).?.name);
    @memcpy(bytes[12..15], "cat");
    var third = try Block.init(&bytes);
    try std.testing.expectError(error.InvalidErofs, third.next(&validator));
}
