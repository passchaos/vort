const std = @import("std");
const input_module = @import("input.zig");
const wire = @import("../xattr.zig");
const format = @import("../format.zig");

pub const Error = wire.Error || input_module.Error;
const Input = input_module.Input;

const Scanner = struct {
    prefix: Input,
    shared: Input,
    block_size: usize,
    shared_block: u32,
    prefix_start: u32,
    prefix_count: u8,
    ibody: []const u8,
    owns_ibody: bool,
    shared_count: usize,
    shared_index: usize = 0,
    inline_position: usize,
    entry: std.ArrayList(u8) = .empty,
    prefix_buffer: [260]u8 = undefined,

    fn init(allocator: std.mem.Allocator, prefix: Input, shared: Input, ibody: Input, block_size: usize, shared_block: u32, prefix_start: u32, prefix_count: u8, ibody_start: usize, ibody_size: usize) Error!Scanner {
        if (ibody_size != 0 and (ibody_size < 12 or ibody_size & 3 != 0)) return error.InvalidErofs;
        _ = try ibody.end(ibody_start, ibody_size);
        const owns = ibody != .slice;
        const bytes: []const u8 = if (!owns) ibody.slice[ibody_start..][0..ibody_size] else data: {
            const storage = try allocator.alloc(u8, ibody_size);
            errdefer allocator.free(storage);
            try ibody.read(ibody_start, storage);
            break :data storage;
        };
        errdefer if (owns) allocator.free(bytes);
        const shared_count: usize = if (bytes.len == 0) 0 else bytes[4];
        const position = if (bytes.len == 0) 0 else try add(12, shared_count * 4);
        if (position > bytes.len) return error.InvalidErofs;
        if (bytes.len != 0) for (bytes[5..12]) |reserved| {
            if (reserved != 0) return error.InvalidErofs;
        };
        return .{ .prefix = prefix, .shared = shared, .block_size = block_size, .shared_block = shared_block, .prefix_start = prefix_start, .prefix_count = prefix_count, .ibody = bytes, .owns_ibody = owns, .shared_count = shared_count, .inline_position = position };
    }

    fn deinit(self: *Scanner, allocator: std.mem.Allocator) void {
        self.entry.deinit(allocator);
        if (self.owns_ibody) allocator.free(self.ibody);
    }

    fn reset(self: *Scanner) void {
        self.shared_index = 0;
        self.inline_position = if (self.ibody.len == 0) 0 else 12 + self.shared_count * 4;
    }

    fn parse(self: *Scanner, bytes: []const u8, start: usize) Error!wire.WireAttribute {
        if (bytes.len -| start < 4) return error.InvalidErofs;
        const name_len = bytes[start];
        const name_index = bytes[start + 1];
        const prefix: []const u8, const infix: []const u8 = if (name_index & 0x80 != 0) blk: {
            const value = try wire.longPrefixAtInput(self.prefix, self.prefix_start, self.prefix_count, name_index & 0x7f, &self.prefix_buffer);
            break :blk .{ value.base, value.infix };
        } else .{ try wire.shortPrefix(name_index, name_len), &.{} };
        return wire.parseEntryWithPrefix(bytes, start, bytes.len, prefix, infix);
    }

    fn next(self: *Scanner, allocator: std.mem.Allocator) Error!?wire.WireAttribute {
        if (self.shared_index < self.shared_count) {
            const id = format.readU32(self.ibody, 12 + self.shared_index * 4);
            self.shared_index += 1;
            const base = std.math.mul(usize, self.shared_block, self.block_size) catch return error.IntegerOverflow;
            const relative = std.math.mul(usize, id, 4) catch return error.IntegerOverflow;
            const start = try add(base, relative);
            if (self.shared == .slice) return try self.parse(self.shared.slice, start);
            var header: [4]u8 = undefined;
            try self.shared.read(start, &header);
            const size = try align4(try add(4, try add(header[0], format.readU16(&header, 2))));
            try self.entry.resize(allocator, size);
            try self.shared.read(start, self.entry.items);
            return try self.parse(self.entry.items, 0);
        }
        if (self.inline_position == self.ibody.len) return null;
        if (allZero(self.ibody[self.inline_position..])) {
            self.inline_position = self.ibody.len;
            return null;
        }
        const entry = try self.parse(self.ibody, self.inline_position);
        self.inline_position = try add(self.inline_position, entry.padded_size);
        return entry;
    }
};

pub fn readAllocLimited(work: std.mem.Allocator, output: std.mem.Allocator, prefix: Input, shared: Input, ibody: Input, block_size: usize, shared_block: u32, prefix_start: u32, prefix_count: u8, ibody_start: usize, ibody_size: usize, max_count: usize, max_bytes: usize) Error!wire.Attributes {
    try wire.validatePrefixTableInput(prefix, prefix_start, prefix_count);
    var scanner = try Scanner.init(work, prefix, shared, ibody, block_size, shared_block, prefix_start, prefix_count, ibody_start, ibody_size);
    defer scanner.deinit(work);
    var count: usize = 0;
    var total: usize = 0;
    while (try scanner.next(work)) |entry| {
        if (count == max_count) return error.OutputLimitExceeded;
        count += 1;
        total = try add(total, try add(try entry.nameLen(), entry.value.len));
        if (total > max_bytes) return error.OutputLimitExceeded;
    }
    const entries = try output.alloc(wire.Attribute, count);
    errdefer output.free(entries);
    const storage = try output.alloc(u8, total);
    errdefer output.free(storage);
    scanner.reset();
    var index: usize = 0;
    var position: usize = 0;
    while (try scanner.next(work)) |entry| {
        if (index >= entries.len) return error.InvalidErofs;
        const name_len = try entry.nameLen();
        const name_end = try add(position, name_len);
        const value_end = try add(name_end, entry.value.len);
        if (value_end > storage.len) return error.InvalidErofs;
        @memcpy(storage[position..][0..entry.prefix.len], entry.prefix);
        const infix = position + entry.prefix.len;
        const suffix = infix + entry.infix.len;
        @memcpy(storage[infix..suffix], entry.infix);
        @memcpy(storage[suffix..name_end], entry.suffix);
        @memcpy(storage[name_end..value_end], entry.value);
        entries[index] = .{ .name = storage[position..name_end], .value = storage[name_end..value_end] };
        for (entries[0..index]) |previous| if (std.mem.eql(u8, previous.name, entries[index].name)) return error.InvalidErofs;
        index += 1;
        position = value_end;
    }
    if (index != entries.len or position != storage.len) return error.InvalidErofs;
    return .{ .allocator = output, .storage = storage, .entries = entries };
}

fn add(a: usize, b: usize) Error!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}

fn align4(value: usize) Error!usize {
    return (try add(value, 3)) & ~@as(usize, 3);
}

fn allZero(bytes: []const u8) bool {
    for (bytes) |byte| if (byte != 0) return false;
    return true;
}
