//! Owned PAX/GNU metadata with a combined retained-byte limit.

const std = @import("std");
const archive = @import("../archive.zig");

pub const Error = std.mem.Allocator.Error || error{
    IntegerOverflow,
    OutputLimitExceeded,
};

pub const OwnedAttributes = struct {
    path: ?[]u8 = null,
    link_path: ?[]u8 = null,
    size: ?u64 = null,
    sparse_major: ?u64 = null,
    sparse_minor: ?u64 = null,
    sparse_name: ?[]u8 = null,
    sparse_size: ?u64 = null,
    sparse_numblocks: ?u64 = null,
    sparse_map: ?[]u8 = null,
    sparse_pax_00: ?[]u8 = null,

    pub fn deinit(self: *OwnedAttributes, allocator: std.mem.Allocator) void {
        freeOptional(allocator, self.path);
        freeOptional(allocator, self.link_path);
        freeOptional(allocator, self.sparse_name);
        freeOptional(allocator, self.sparse_map);
        freeOptional(allocator, self.sparse_pax_00);
        self.* = .{};
    }

    pub fn view(self: *const OwnedAttributes) archive.Attributes {
        return .{
            .path = self.path,
            .link_path = self.link_path,
            .size = self.size,
            .sparse_major = self.sparse_major,
            .sparse_minor = self.sparse_minor,
            .sparse_name = self.sparse_name,
            .sparse_size = self.sparse_size,
            .sparse_numblocks = self.sparse_numblocks,
            .sparse_map = self.sparse_map,
            .sparse_pax_00 = self.sparse_pax_00,
        };
    }

    pub fn byteLen(self: *const OwnedAttributes) Error!usize {
        var total: usize = 0;
        inline for (.{ self.path, self.link_path, self.sparse_name, self.sparse_map, self.sparse_pax_00 }) |value| {
            if (value) |bytes| {
                total = std.math.add(usize, total, bytes.len) catch
                    return error.IntegerOverflow;
            }
        }
        return total;
    }

    pub fn apply(
        self: *OwnedAttributes,
        allocator: std.mem.Allocator,
        parsed: archive.Attributes,
        other_size: usize,
        limit: usize,
    ) Error!void {
        var final_size = try self.byteLen();
        final_size = try replacementSize(final_size, self.path, parsed.path);
        final_size = try replacementSize(final_size, self.link_path, parsed.link_path);
        final_size = try replacementSize(final_size, self.sparse_name, parsed.sparse_name);
        final_size = try replacementSize(final_size, self.sparse_map, parsed.sparse_map);
        final_size = try replacementSize(final_size, self.sparse_pax_00, parsed.sparse_pax_00);
        const combined = std.math.add(usize, final_size, other_size) catch
            return error.IntegerOverflow;
        if (combined > limit) return error.OutputLimitExceeded;

        if (parsed.path) |value| try replaceOptional(allocator, &self.path, value);
        if (parsed.link_path) |value| try replaceOptional(allocator, &self.link_path, value);
        if (parsed.sparse_name) |value| try replaceOptional(allocator, &self.sparse_name, value);
        if (parsed.sparse_map) |value| try replaceOptional(allocator, &self.sparse_map, value);
        if (parsed.sparse_pax_00) |value| try replaceOptional(allocator, &self.sparse_pax_00, value);
        if (parsed.size) |value| self.size = value;
        if (parsed.sparse_major) |value| self.sparse_major = value;
        if (parsed.sparse_minor) |value| self.sparse_minor = value;
        if (parsed.sparse_size) |value| self.sparse_size = value;
        if (parsed.sparse_numblocks) |value| self.sparse_numblocks = value;
    }

    pub fn setPath(
        self: *OwnedAttributes,
        allocator: std.mem.Allocator,
        value: []const u8,
        other_size: usize,
        limit: usize,
    ) Error!void {
        const final_size = try replacementSize(try self.byteLen(), self.path, value);
        const combined = std.math.add(usize, final_size, other_size) catch
            return error.IntegerOverflow;
        if (combined > limit) return error.OutputLimitExceeded;
        try replaceOptional(allocator, &self.path, value);
    }

    pub fn setLinkPath(
        self: *OwnedAttributes,
        allocator: std.mem.Allocator,
        value: []const u8,
        other_size: usize,
        limit: usize,
    ) Error!void {
        const final_size = try replacementSize(try self.byteLen(), self.link_path, value);
        const combined = std.math.add(usize, final_size, other_size) catch
            return error.IntegerOverflow;
        if (combined > limit) return error.OutputLimitExceeded;
        try replaceOptional(allocator, &self.link_path, value);
    }
};

fn freeOptional(allocator: std.mem.Allocator, value: ?[]u8) void {
    if (value) |bytes| allocator.free(bytes);
}

fn replaceOptional(
    allocator: std.mem.Allocator,
    target: *?[]u8,
    value: []const u8,
) std.mem.Allocator.Error!void {
    const replacement = try allocator.dupe(u8, value);
    if (target.*) |previous| allocator.free(previous);
    target.* = replacement;
}

fn replacementSize(total: usize, old: ?[]u8, replacement: ?[]const u8) Error!usize {
    const value = replacement orelse return total;
    const without_old = total - if (old) |bytes| bytes.len else 0;
    return std.math.add(usize, without_old, value.len) catch error.IntegerOverflow;
}
