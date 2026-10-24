//! Bounded DEX code-item and Dalvik instruction reference parsing.

const std = @import("std");
const intel = @import("intel.zig");
const types = @import("dex_types.zig");

pub const Reference = intel.Reference;
pub const ReferenceLists = [types.reference_type_count]std.ArrayList(Reference);

pub const Error = std.mem.Allocator.Error || error{
    InvalidDex,
    IntegerOverflow,
    OutputLimitExceeded,
};

pub fn parseCodeItemsAlloc(
    allocator: std.mem.Allocator,
    image: []const u8,
    map: types.MapItem,
    max_items: usize,
) Error![]u32 {
    if (map.count == 0 or map.count > max_items or
        !rangeFitsArray(map.offset, map.count, 16, image.len))
    {
        return error.InvalidDex;
    }
    const output = try allocator.alloc(u32, map.count);
    errdefer allocator.free(output);
    var cursor: usize = map.offset;
    for (output) |*item_offset| {
        cursor = try alignForward(cursor, 4, image.len);
        if (!rangeFits(cursor, 16, image.len)) return error.InvalidDex;
        item_offset.* = @intCast(cursor);
        const tries_size = readU16(image, cursor + 6);
        const instruction_units: usize = readU32(image, cursor + 12);
        cursor += 16;
        const instruction_bytes = std.math.mul(usize, instruction_units, 2) catch
            return error.IntegerOverflow;
        if (!rangeFits(cursor, instruction_bytes, image.len)) return error.InvalidDex;
        cursor += instruction_bytes;
        if (tries_size == 0) continue;
        cursor = try alignForward(cursor, 4, image.len);
        const tries_bytes = std.math.mul(usize, tries_size, 8) catch
            return error.IntegerOverflow;
        if (!rangeFits(cursor, tries_bytes, image.len)) return error.InvalidDex;
        cursor += tries_bytes;
        const handlers_size = try readUleb(image, &cursor);
        if (handlers_size > image.len - cursor) return error.InvalidDex;
        for (0..handlers_size) |_| {
            const handler_count = try readSleb(image, &cursor);
            const magnitude: u32 = if (handler_count < 0)
                @intCast(-@as(i64, handler_count))
            else
                @intCast(handler_count);
            if (magnitude > image.len - cursor) return error.InvalidDex;
            for (0..magnitude) |_| {
                _ = try readUleb(image, &cursor);
                _ = try readUleb(image, &cursor);
            }
            if (handler_count <= 0) _ = try readUleb(image, &cursor);
        }
    }
    return output;
}

pub fn collectReferences(
    allocator: std.mem.Allocator,
    image: []const u8,
    maps: types.Maps,
    code_offsets: []const u32,
    lists: *ReferenceLists,
    max_references: usize,
) Error!void {
    for (code_offsets) |code_offset| {
        if (!rangeFits(code_offset, 16, image.len)) return error.InvalidDex;
        const instruction_units: usize = readU32(image, code_offset + 12);
        const start: usize = code_offset + 16;
        const instruction_bytes = std.math.mul(usize, instruction_units, 2) catch
            return error.IntegerOverflow;
        if (!rangeFits(start, instruction_bytes, image.len)) return error.InvalidDex;
        const end = start + instruction_bytes;
        var payload_boundary = end;
        var cursor = start;
        while (cursor < payload_boundary) {
            const instruction = types.instruction(image[cursor]) orelse break;
            const length = @as(usize, instruction.units) * 2;
            if (!rangeFits(cursor, length, end)) break;
            if (instruction.opcode == 0x26 or instruction.opcode == 0x2b or
                instruction.opcode == 0x2c)
            {
                const delta = readI32(image, cursor + 2);
                if (delta < instruction.units or
                    @as(u32, @intCast(delta)) >= (end - cursor) / 2)
                {
                    break;
                }
                payload_boundary = @min(
                    payload_boundary,
                    cursor + @as(usize, @intCast(delta)) * 2,
                );
            }
            if (instruction.format == .c)
                try collectIndexInstruction(
                    allocator,
                    image,
                    maps,
                    cursor,
                    instruction,
                    lists,
                    max_references,
                );
            if (instruction.format == .t)
                try collectRelativeInstruction(
                    allocator,
                    image,
                    cursor,
                    instruction,
                    lists,
                    max_references,
                );
            cursor += length;
        }
    }
}

fn collectIndexInstruction(
    allocator: std.mem.Allocator,
    image: []const u8,
    maps: types.Maps,
    offset: usize,
    instruction: types.Instruction,
    lists: *ReferenceLists,
    max_references: usize,
) Error!void {
    switch (instruction.opcode) {
        0x1a => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.string,
            4,
            .code_string16,
            lists,
            max_references,
        ),
        0x1b => try appendIndex(
            allocator,
            image,
            offset + 2,
            4,
            maps.string,
            4,
            .code_string32,
            lists,
            max_references,
        ),
        0x1c, 0x1f, 0x20, 0x22, 0x24 => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.type_id,
            4,
            .code_type,
            lists,
            max_references,
        ),
        0xfa, 0xfb => {
            try appendIndex(
                allocator,
                image,
                offset + 2,
                2,
                maps.method,
                8,
                .code_method,
                lists,
                max_references,
            );
            try appendIndex(
                allocator,
                image,
                offset + 6,
                2,
                maps.proto,
                12,
                .code_proto,
                lists,
                max_references,
            );
        },
        0xff => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.proto,
            12,
            .code_proto,
            lists,
            max_references,
        ),
        0xfc => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.call_site,
            4,
            .code_call_site,
            lists,
            max_references,
        ),
        0xfe => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.method_handle,
            8,
            .code_method_handle,
            lists,
            max_references,
        ),
        0x52 => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.field,
            8,
            .code_field,
            lists,
            max_references,
        ),
        0x60 => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.field,
            8,
            .code_field,
            lists,
            max_references,
        ),
        0x6e, 0x74 => try appendIndex(
            allocator,
            image,
            offset + 2,
            2,
            maps.method,
            8,
            .code_method,
            lists,
            max_references,
        ),
        else => {},
    }
}

fn collectRelativeInstruction(
    allocator: std.mem.Allocator,
    image: []const u8,
    offset: usize,
    instruction: types.Instruction,
    lists: *ReferenceLists,
    max_references: usize,
) Error!void {
    switch (instruction.opcode) {
        0x28 => {
            const location = offset + 1;
            const delta: i32 = @as(i8, @bitCast(image[location]));
            const target_value = @as(i64, @intCast(location)) +
                (@as(i64, delta) - 1) * 2;
            const target: u32 = @truncate(@as(u64, @bitCast(target_value)));
            try appendReference(
                allocator,
                .code_relative8,
                @intCast(location),
                target,
                lists,
                max_references,
            );
        },
        0x29, 0x32, 0x38 => {
            const location = offset + 2;
            const delta: i32 = readI16(image, location);
            const target_value = @as(i64, @intCast(location)) +
                (@as(i64, delta) - 1) * 2;
            const target: u32 = @truncate(@as(u64, @bitCast(target_value)));
            try appendReference(
                allocator,
                .code_relative16,
                @intCast(location),
                target,
                lists,
                max_references,
            );
        },
        0x26, 0x2a, 0x2b, 0x2c => {
            const location = offset + 2;
            const delta: i64 = readI32(image, location);
            const target = @as(i64, @intCast(location)) + (delta - 1) * 2;
            if (target < 0 or target >= intel.offset_bound) return;
            try appendReference(
                allocator,
                .code_relative32,
                @intCast(location),
                @intCast(target),
                lists,
                max_references,
            );
        },
        else => {},
    }
}

fn appendIndex(
    allocator: std.mem.Allocator,
    image: []const u8,
    location: usize,
    width: u3,
    target_map: types.MapItem,
    item_size: u8,
    reference_type: types.ReferenceType,
    lists: *ReferenceLists,
    max_references: usize,
) Error!void {
    const index: u32 = switch (width) {
        2 => readU16(image, location),
        4 => readU32(image, location),
        else => unreachable,
    };
    if (index >= target_map.count) return;
    const target = @as(u64, target_map.offset) + @as(u64, index) * item_size;
    if (target > std.math.maxInt(u32)) return;
    try appendReference(
        allocator,
        reference_type,
        @intCast(location),
        @intCast(target),
        lists,
        max_references,
    );
}

fn appendReference(
    allocator: std.mem.Allocator,
    reference_type: types.ReferenceType,
    location: u32,
    target: u32,
    lists: *ReferenceLists,
    max_references: usize,
) Error!void {
    const output = &lists[@intFromEnum(reference_type)];
    if (output.items.len >= max_references) return error.OutputLimitExceeded;
    try output.append(allocator, .{ .location = location, .target = target });
}

fn readUleb(image: []const u8, cursor: *usize) Error!u32 {
    var value: u32 = 0;
    for (0..5) |index| {
        if (cursor.* >= image.len) return error.InvalidDex;
        const byte = image[cursor.*];
        cursor.* += 1;
        value |= @as(u32, byte & 0x7f) << @intCast(index * 7);
        if (byte & 0x80 == 0) return value;
    }
    return error.InvalidDex;
}

fn readSleb(image: []const u8, cursor: *usize) Error!i32 {
    var value: u32 = 0;
    var byte: u8 = 0;
    var shift: u6 = 0;
    for (0..5) |_| {
        if (cursor.* >= image.len) return error.InvalidDex;
        byte = image[cursor.*];
        cursor.* += 1;
        value |= @as(u32, byte & 0x7f) << @as(u5, @intCast(shift));
        shift += 7;
        if (byte & 0x80 == 0) {
            if (shift < 32 and byte & 0x40 != 0)
                value |= @as(u32, std.math.maxInt(u32)) <<
                    @as(u5, @intCast(shift));
            return @bitCast(value);
        }
    }
    return error.InvalidDex;
}

fn alignForward(value: usize, alignment: usize, limit: usize) Error!usize {
    const aligned = std.mem.alignForward(usize, value, alignment);
    if (aligned > limit) return error.InvalidDex;
    return aligned;
}

fn rangeFitsArray(offset: anytype, count: anytype, width: usize, total: usize) bool {
    const n = std.math.cast(usize, count) orelse return false;
    const bytes = std.math.mul(usize, n, width) catch return false;
    return rangeFits(offset, bytes, total);
}

fn rangeFits(offset: anytype, length: anytype, total: usize) bool {
    const start = std.math.cast(usize, offset) orelse return false;
    const size = std.math.cast(usize, length) orelse return false;
    return start <= total and size <= total - start;
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readI16(bytes: []const u8, offset: usize) i16 {
    return std.mem.readInt(i16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn readI32(bytes: []const u8, offset: usize) i32 {
    return std.mem.readInt(i32, bytes[offset..][0..4], .little);
}

test "Zucchini DEX instruction metadata preserves reference opcode families" {
    try std.testing.expectEqual(@as(u8, 0x52), types.instruction(0x5f).?.opcode);
    try std.testing.expectEqual(@as(u8, 0x6e), types.instruction(0x72).?.opcode);
    try std.testing.expectEqual(@as(u8, 0x2b), types.instruction(0x2b).?.opcode);
    try std.testing.expectEqual(@as(u8, 0xff), types.instruction(0xff).?.opcode);
    try std.testing.expect(types.instruction(0x3e) == null);
}
