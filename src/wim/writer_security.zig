const std = @import("std");
const core = @import("../core.zig");
const tree_mod = @import("writer_tree.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{InvalidWimEntry};

const descriptor_header_size: usize = 20;
const sid_header_size: usize = 8;
const acl_header_size: usize = 8;
const self_relative: u16 = 0x8000;
const dacl_present: u16 = 0x0004;
const sacl_present: u16 = 0x0010;

pub const Table = struct {
    allocator: std.mem.Allocator,
    descriptors: [][]const u8,

    pub fn deinit(self: *Table) void {
        self.allocator.free(self.descriptors);
        self.* = undefined;
    }
};

pub fn plan(
    allocator: std.mem.Allocator,
    tree: *tree_mod.Tree,
) Error!Table {
    var descriptors: std.ArrayList([]const u8) = .empty;
    errdefer descriptors.deinit(allocator);
    for (tree.nodes) |*node| {
        const descriptor = node.security_descriptor orelse {
            node.security_id = null;
            continue;
        };
        try validateDescriptor(descriptor);
        var selected: ?usize = null;
        for (descriptors.items, 0..) |existing, index| {
            if (std.mem.eql(u8, existing, descriptor)) {
                selected = index;
                break;
            }
        }
        const index = selected orelse blk: {
            if (descriptors.items.len >= 0x8000_0000)
                return error.InvalidWimEntry;
            try descriptors.append(allocator, descriptor);
            break :blk descriptors.items.len - 1;
        };
        node.security_id = @intCast(index);
    }
    return .{
        .allocator = allocator,
        .descriptors = try descriptors.toOwnedSlice(allocator),
    };
}

pub fn encodedLength(descriptors: []const []const u8) Error!usize {
    var length = std.math.add(
        usize,
        8,
        std.math.mul(usize, descriptors.len, 8) catch
            return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    for (descriptors) |descriptor| {
        if (descriptor.len > std.math.maxInt(u32))
            return error.InvalidWimEntry;
        length = std.math.add(usize, length, descriptor.len) catch
            return error.IntegerOverflow;
    }
    const aligned = std.math.add(usize, length, 7) catch
        return error.IntegerOverflow;
    const result = aligned & ~@as(usize, 7);
    if (result > std.math.maxInt(u32)) return error.InvalidWimEntry;
    return result;
}

pub fn write(
    output: []u8,
    descriptors: []const []const u8,
) Error!usize {
    const length = try encodedLength(descriptors);
    if (output.len < length) return error.OutputTooSmall;
    @memset(output[0..length], 0);
    writeU32(output, 0, if (descriptors.len == 0) 0 else @intCast(length));
    if (descriptors.len > std.math.maxInt(u32)) return error.InvalidWimEntry;
    writeU32(output, 4, @intCast(descriptors.len));
    var data_offset = 8 + descriptors.len * 8;
    for (descriptors, 0..) |descriptor, index| {
        writeU64(output, 8 + index * 8, descriptor.len);
        @memcpy(output[data_offset..][0..descriptor.len], descriptor);
        data_offset += descriptor.len;
    }
    return length;
}

pub fn validateDescriptor(descriptor: []const u8) Error!void {
    if (descriptor.len < descriptor_header_size or descriptor.len > std.math.maxInt(u32) or
        descriptor[0] != 1)
        return error.InvalidWimEntry;
    const control = readU16(descriptor, 2);
    if (control & self_relative == 0) return error.InvalidWimEntry;
    try validateSid(descriptor, readU32(descriptor, 4));
    try validateSid(descriptor, readU32(descriptor, 8));
    try validateAcl(
        descriptor,
        readU32(descriptor, 12),
        control & sacl_present != 0,
    );
    try validateAcl(
        descriptor,
        readU32(descriptor, 16),
        control & dacl_present != 0,
    );
}

fn validateSid(descriptor: []const u8, raw_offset: u32) Error!void {
    if (raw_offset == 0) return;
    const offset: usize = raw_offset;
    if (offset < descriptor_header_size or descriptor.len -| offset < sid_header_size)
        return error.InvalidWimEntry;
    if (descriptor[offset] != 1) return error.InvalidWimEntry;
    const sub_authority_count: usize = descriptor[offset + 1];
    const size = std.math.add(
        usize,
        sid_header_size,
        std.math.mul(usize, sub_authority_count, 4) catch
            return error.IntegerOverflow,
    ) catch return error.IntegerOverflow;
    if (descriptor.len - offset < size) return error.InvalidWimEntry;
}

fn validateAcl(
    descriptor: []const u8,
    raw_offset: u32,
    present: bool,
) Error!void {
    if (!present) {
        if (raw_offset != 0) return error.InvalidWimEntry;
        return;
    }
    if (raw_offset == 0) return; // A present null ACL is valid.
    const offset: usize = raw_offset;
    if (offset < descriptor_header_size or descriptor.len -| offset < acl_header_size)
        return error.InvalidWimEntry;
    const acl_size: usize = readU16(descriptor, offset + 2);
    if (acl_size < acl_header_size or descriptor.len - offset < acl_size)
        return error.InvalidWimEntry;
    const ace_count: usize = readU16(descriptor, offset + 4);
    var ace_offset = offset + acl_header_size;
    const acl_end = offset + acl_size;
    for (0..ace_count) |_| {
        if (acl_end -| ace_offset < 4) return error.InvalidWimEntry;
        const ace_size: usize = readU16(descriptor, ace_offset + 2);
        if (ace_size < 4 or acl_end - ace_offset < ace_size)
            return error.InvalidWimEntry;
        ace_offset += ace_size;
    }
    if (ace_offset > acl_end) return error.InvalidWimEntry;
}

fn readU16(input: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, input[offset..][0..2], .little);
}

fn readU32(input: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, input[offset..][0..4], .little);
}

fn writeU32(output: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, output[offset..][0..4], value, .little);
}

fn writeU64(output: []u8, offset: usize, value: anytype) void {
    std.mem.writeInt(u64, output[offset..][0..8], @intCast(value), .little);
}

test "WIM writer security table validates and deduplicates descriptors" {
    const descriptor = [_]u8{ 1, 0, 4, 0x80 } ++ [_]u8{0} ** 16;
    const entries = [_]tree_mod.Entry{
        .{ .path = "a", .security_descriptor = &descriptor },
        .{ .path = "b", .security_descriptor = &descriptor },
    };
    var tree = try tree_mod.build(std.testing.allocator, &entries, .{
        .security_descriptor = &descriptor,
    });
    defer tree.deinit();
    var table = try plan(std.testing.allocator, &tree);
    defer table.deinit();
    try std.testing.expectEqual(@as(usize, 1), table.descriptors.len);
    try std.testing.expectEqual(@as(?u32, 0), tree.nodes[0].security_id);
    try std.testing.expectEqual(@as(?u32, 0), tree.nodes[1].security_id);
    try std.testing.expectEqual(@as(?u32, 0), tree.nodes[2].security_id);
}
