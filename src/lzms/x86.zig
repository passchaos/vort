const std = @import("std");

const id_window_size: i32 = 65_535;
const max_translation_offset: i32 = 1_023;

pub fn undo(data: []u8, last_target_usages: *[65_536]i32) void {
    if (data.len <= 17) return;
    @memset(last_target_usages, -id_window_size - 1);
    var last_x86_position: i32 = -max_translation_offset - 1;
    var position: usize = 1;
    const tail = data.len - 16;
    while (true) {
        while (position < tail and !isPotentialOpcode(data[position]))
            position += 1;
        if (position >= tail) break;
        position = translateIfNeeded(
            data,
            position,
            &last_x86_position,
            last_target_usages,
        );
    }
}

fn isPotentialOpcode(byte: u8) bool {
    return byte == 0x48 or byte == 0x4c or byte == 0xe8 or byte == 0xe9 or
        byte == 0xf0 or byte == 0xff;
}

fn translateIfNeeded(
    data: []u8,
    position: usize,
    last_x86_position: *i32,
    last_target_usages: *[65_536]i32,
) usize {
    var max_offset = max_translation_offset;
    var opcode_bytes: usize = undefined;
    const opcode = data[position];
    if (opcode >= 0xf0) {
        if (opcode & 0x0f != 0) {
            if (data[position + 1] == 0x15) {
                opcode_bytes = 2;
            } else {
                return position + 1;
            }
        } else if (data[position + 1] == 0x83 and data[position + 2] == 0x05) {
            opcode_bytes = 3;
        } else {
            return position + 1;
        }
    } else if (opcode <= 0x4c) {
        if (data[position + 2] & 0x07 == 0x05 and
            (data[position + 1] == 0x8d or
                (data[position + 1] == 0x8b and opcode & 0x04 == 0 and
                    data[position + 2] & 0xf0 == 0)))
        {
            opcode_bytes = 3;
        } else {
            return position + 1;
        }
    } else if (opcode & 1 != 0) {
        return position + 5;
    } else {
        opcode_bytes = 1;
        max_offset >>= 1;
    }

    const instruction_position: i32 = @intCast(position);
    const operand = position + opcode_bytes;
    if (instruction_position - last_x86_position.* <= max_offset) {
        const absolute = readU32(data, operand);
        writeU32(data, operand, absolute -% @as(u32, @intCast(instruction_position)));
    }
    const target: u16 = @truncate(
        @as(u32, @intCast(instruction_position)) +% readU16(data, operand),
    );
    const likely_instruction_position: i32 = @intCast(
        position + opcode_bytes + @sizeOf(u32) - 1,
    );
    if (likely_instruction_position - last_target_usages[target] <= id_window_size)
        last_x86_position.* = likely_instruction_position;
    last_target_usages[target] = likely_instruction_position;
    return operand + @sizeOf(u32);
}

fn readU16(bytes: []const u8, offset: usize) u16 {
    return std.mem.readInt(u16, bytes[offset..][0..2], .little);
}

fn readU32(bytes: []const u8, offset: usize) u32 {
    return std.mem.readInt(u32, bytes[offset..][0..4], .little);
}

fn writeU32(bytes: []u8, offset: usize, value: u32) void {
    std.mem.writeInt(u32, bytes[offset..][0..4], value, .little);
}

test "LZMS x86 filter restores translated repeated targets" {
    var data: [64]u8 = @splat(0x90);
    const positions = [_]usize{ 1, 10, 20 };
    const target: u32 = 48;
    for (positions, 0..) |position, index| {
        data[position] = 0xe8;
        const relative = target - @as(u32, @intCast(position));
        writeU32(&data, position + 1, if (index == 2) target else relative);
    }
    var scratch: [65_536]i32 = undefined;
    undo(&data, &scratch);
    for (positions) |position|
        try std.testing.expectEqual(
            target - @as(u32, @intCast(position)),
            readU32(&data, position + 1),
        );
}
