const std = @import("std");
const core = @import("../core.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar29Stream,
};

pub const default_max_instructions: usize = 25_000_000;

const memory_size: usize = 0x40000;
const memory_mask: u32 = 0x3ffff;
const global_base: usize = 0x3c000;
const system_global_size: usize = 64;
const max_user_global: usize = 0x2000 - system_global_size;
const max_static_data: usize = memory_size - global_base;
const flag_carry: u32 = 1;
const flag_zero: u32 = 2;
const flag_sign: u32 = 0x8000_0000;

const Opcode = enum(u8) {
    mov,
    cmp,
    add,
    sub,
    jz,
    jnz,
    inc,
    dec,
    jmp,
    xor,
    and_,
    or_,
    test_,
    js,
    jns,
    jb,
    jbe,
    ja,
    jae,
    push,
    pop,
    call,
    ret,
    not,
    shl,
    shr,
    sar,
    neg,
    pusha,
    popa,
    pushf,
    popf,
    movzx,
    movsx,
    xchg,
    mul,
    div,
    adc,
    sbb,
    print,

    fn fromByte(value: u8) Error!Opcode {
        if (value > @intFromEnum(Opcode.print)) return error.InvalidRar29Stream;
        return @enumFromInt(value);
    }

    fn operandCount(self: Opcode) u2 {
        return switch (self) {
            .ret, .pusha, .popa, .pushf, .popf, .print => 0,
            .jz,
            .jnz,
            .inc,
            .dec,
            .jmp,
            .js,
            .jns,
            .jb,
            .jbe,
            .ja,
            .jae,
            .push,
            .pop,
            .call,
            .not,
            .neg,
            => 1,
            else => 2,
        };
    }

    fn supportsByteMode(self: Opcode) bool {
        return switch (self) {
            .mov,
            .cmp,
            .add,
            .sub,
            .inc,
            .dec,
            .xor,
            .and_,
            .or_,
            .test_,
            .not,
            .shl,
            .shr,
            .sar,
            .neg,
            .xchg,
            .mul,
            .div,
            .adc,
            .sbb,
            => true,
            else => false,
        };
    }

    fn isJumpOrCall(self: Opcode) bool {
        return switch (self) {
            .jz, .jnz, .jmp, .js, .jns, .jb, .jbe, .ja, .jae, .call => true,
            else => false,
        };
    }

    fn terminatesProgram(self: Opcode) bool {
        return self == .jmp or self == .ret;
    }
};

const Operand = union(enum) {
    register: u3,
    immediate: u32,
    register_indirect: u3,
    indexed: struct { register: u3, base: u32 },
    absolute: u32,
};

const Instruction = struct {
    opcode: Opcode,
    byte_mode: bool,
    operands: [2]Operand = undefined,
    operand_count: u2,
};

pub const Program = struct {
    allocator: std.mem.Allocator,
    static_data: []u8,
    instructions: []Instruction,

    pub fn parse(allocator: std.mem.Allocator, blob: []const u8) Error!Program {
        if (blob.len == 0) return error.InvalidRar29Stream;
        var checksum: u8 = 0;
        for (blob) |byte| checksum ^= byte;
        if (checksum != 0) return error.InvalidRar29Stream;

        var bits = BitReader{ .input = blob[1..] };
        var static_data: []u8 = &.{};
        errdefer if (static_data.len != 0) allocator.free(static_data);
        if (try bits.read(1) != 0) {
            const static_size = std.math.add(u32, try bits.readVmNumber(), 1) catch
                return error.IntegerOverflow;
            if (static_size > max_static_data) return error.InvalidRar29Stream;
            static_data = try allocator.alloc(u8, static_size);
            for (static_data) |*byte| byte.* = @intCast(try bits.read(8));
        }

        var instructions: std.ArrayList(Instruction) = .empty;
        defer instructions.deinit(allocator);
        while (bits.remaining() >= 8) {
            const instruction = parseInstruction(&bits, instructions.items.len) catch |err| switch (err) {
                error.TruncatedFrame => break,
                else => return err,
            };
            try instructions.append(allocator, instruction);
        }
        if (instructions.items.len == 0 or
            !instructions.items[instructions.items.len - 1].opcode.terminatesProgram())
            try instructions.append(allocator, .{
                .opcode = .ret,
                .byte_mode = false,
                .operand_count = 0,
            });
        const owned_instructions = try instructions.toOwnedSlice(allocator);
        return .{
            .allocator = allocator,
            .static_data = static_data,
            .instructions = owned_instructions,
        };
    }

    pub fn deinit(self: *Program) void {
        if (self.static_data.len != 0) self.allocator.free(self.static_data);
        self.allocator.free(self.instructions);
        self.* = undefined;
    }

    pub fn execute(
        self: *const Program,
        allocator: std.mem.Allocator,
        input: []const u8,
        initial_regs: [7]u32,
        global_data: []const u8,
        file_offset: u64,
        exec_count: u32,
        max_instructions: usize,
    ) Error!ExecutionResult {
        var vm = try Vm.init(
            allocator,
            self,
            input,
            initial_regs,
            global_data,
            file_offset,
            exec_count,
        );
        defer vm.deinit();
        return vm.run(self, max_instructions);
    }
};

pub const ExecutionResult = struct {
    allocator: std.mem.Allocator,
    output: []u8,
    globals: []u8,

    pub fn deinit(self: *ExecutionResult) void {
        self.allocator.free(self.output);
        self.allocator.free(self.globals);
        self.* = undefined;
    }
};

fn parseInstruction(bits: *BitReader, instruction_index: usize) Error!Instruction {
    const opcode = if (try bits.read(1) == 0)
        try Opcode.fromByte(@intCast(try bits.read(3)))
    else
        try Opcode.fromByte(@as(u8, @intCast(try bits.read(5))) + 8);
    const byte_mode = opcode.supportsByteMode() and try bits.read(1) != 0;
    var result = Instruction{
        .opcode = opcode,
        .byte_mode = byte_mode,
        .operand_count = opcode.operandCount(),
    };
    for (0..result.operand_count) |index| {
        var operand = try parseOperand(bits, byte_mode);
        if (index == 0 and opcode.isJumpOrCall()) {
            if (operand == .immediate)
                operand = .{ .immediate = remapJumpTarget(operand.immediate, instruction_index) };
        }
        result.operands[index] = operand;
    }
    return result;
}

fn parseOperand(bits: *BitReader, byte_mode: bool) Error!Operand {
    if (try bits.read(1) != 0)
        return .{ .register = @intCast(try bits.read(3)) };
    if (try bits.read(1) == 0)
        return .{ .immediate = if (byte_mode) try bits.read(8) else try bits.readVmNumber() };
    if (try bits.read(1) == 0)
        return .{ .register_indirect = @intCast(try bits.read(3)) };
    if (try bits.read(1) == 0)
        return .{ .indexed = .{
            .register = @intCast(try bits.read(3)),
            .base = try bits.readVmNumber(),
        } };
    return .{ .absolute = try bits.readVmNumber() };
}

fn remapJumpTarget(value: u32, instruction_index: usize) u32 {
    if (value >= 256) return value - 256;
    var distance: i64 = value;
    if (distance >= 136)
        distance -= 264
    else if (distance >= 16)
        distance -= 8
    else if (distance >= 8)
        distance -= 16;
    const target = @as(i64, @intCast(instruction_index)) +% distance;
    return @bitCast(@as(i32, @truncate(target)));
}

const Vm = struct {
    allocator: std.mem.Allocator,
    memory: []u8,
    regs: [8]u32,
    flags: u32 = 0,

    fn init(
        allocator: std.mem.Allocator,
        program: *const Program,
        input: []const u8,
        initial_regs: [7]u32,
        global_data: []const u8,
        file_offset: u64,
        exec_count: u32,
    ) Error!Vm {
        if (input.len > global_base) return error.InvalidRar29Stream;
        const memory = try allocator.alloc(u8, memory_size);
        errdefer allocator.free(memory);
        @memset(memory, 0);
        @memcpy(memory[0..input.len], input);
        const copied_global_len = @min(global_data.len, 0x2000);
        @memcpy(
            memory[global_base..][0..copied_global_len],
            global_data[0..copied_global_len],
        );
        const global_len = @max(copied_global_len, system_global_size);
        const static_start = global_base + global_len;
        const static_len = @min(program.static_data.len, memory_size - static_start);
        @memcpy(memory[static_start..][0..static_len], program.static_data[0..static_len]);

        var regs: [8]u32 = @splat(0);
        @memcpy(regs[0..7], &initial_regs);
        regs[3] = global_base;
        regs[4] = @intCast(input.len);
        regs[5] = exec_count;
        regs[6] = @truncate(file_offset);
        regs[7] = memory_size;
        for (regs[0..7], 0..) |value, index|
            writeU32(memory, global_base + index * 4, value);
        writeU32(memory, global_base + 0x1c, @intCast(input.len));
        writeU32(memory, global_base + 0x20, 0);
        writeU32(memory, global_base + 0x24, @truncate(file_offset));
        writeU32(memory, global_base + 0x28, @truncate(file_offset >> 32));
        writeU32(memory, global_base + 0x2c, exec_count);
        return .{ .allocator = allocator, .memory = memory, .regs = regs };
    }

    fn deinit(self: *Vm) void {
        self.allocator.free(self.memory);
        self.* = undefined;
    }

    fn run(self: *Vm, program: *const Program, max_instructions: usize) Error!ExecutionResult {
        var instruction_pointer: usize = 0;
        var terminated = false;
        for (0..max_instructions) |_| {
            if (instruction_pointer >= program.instructions.len) {
                terminated = true;
                break;
            }
            const instruction = &program.instructions[instruction_pointer];
            instruction_pointer += 1;
            if (try self.executeInstruction(instruction, instruction_pointer)) |next| {
                if (next >= program.instructions.len) {
                    terminated = true;
                    break;
                }
                instruction_pointer = next;
            }
            if (instruction.opcode == .ret and self.regs[7] >= memory_size) {
                terminated = true;
                break;
            }
        }
        if (!terminated) return error.InvalidRar29Stream;

        var output_position = @as(usize, self.readU32(global_base + 0x20) & memory_mask);
        var output_size = @as(usize, self.readU32(global_base + 0x1c) & memory_mask);
        const output_end = std.math.add(usize, output_position, output_size) catch memory_size + 1;
        if (output_end >= memory_size) {
            output_position = 0;
            output_size = 0;
        }
        const output = try self.allocator.dupe(
            u8,
            self.memory[output_position .. output_position + output_size],
        );
        errdefer self.allocator.free(output);
        const user_global = @min(
            @as(usize, self.readU32(global_base + 0x30)),
            max_user_global,
        );
        const globals = if (user_global == 0)
            try self.allocator.alloc(u8, 0)
        else
            try self.allocator.dupe(
                u8,
                self.memory[global_base .. global_base + system_global_size + user_global],
            );
        return .{ .allocator = self.allocator, .output = output, .globals = globals };
    }

    fn executeInstruction(
        self: *Vm,
        instruction: *const Instruction,
        instruction_pointer: usize,
    ) Error!?usize {
        const byte_mode = instruction.byte_mode;
        const operand = struct {
            fn get(value: *const Instruction, index: usize) Error!*const Operand {
                if (index >= value.operand_count) return error.InvalidRar29Stream;
                return &value.operands[index];
            }
        }.get;
        const first = if (instruction.operand_count > 0)
            try operand(instruction, 0)
        else
            undefined;
        const second = if (instruction.operand_count > 1)
            try operand(instruction, 1)
        else
            undefined;
        switch (instruction.opcode) {
            .mov => try self.writeOperand(first, self.readOperand(second, byte_mode), byte_mode),
            .cmp => self.setSubFlags(
                self.readOperand(first, byte_mode),
                self.readOperand(second, byte_mode),
                0,
                byte_mode,
            ),
            .add => {
                const a = self.readOperand(first, byte_mode);
                const b = self.readOperand(second, byte_mode);
                const result = self.maskWidth(a +% b, byte_mode);
                try self.writeOperand(first, result, byte_mode);
                self.setAddFlags(a, b, 0, result, byte_mode);
            },
            .sub => {
                const a = self.readOperand(first, byte_mode);
                const b = self.readOperand(second, byte_mode);
                const result = self.maskWidth(a -% b, byte_mode);
                try self.writeOperand(first, result, byte_mode);
                self.setSubFlags(a, b, 0, byte_mode);
            },
            .jz => return self.conditionalJump(first, self.flags & flag_zero != 0),
            .jnz => return self.conditionalJump(first, self.flags & flag_zero == 0),
            .inc, .dec => {
                const value = self.readOperand(first, byte_mode);
                const result = self.maskWidth(
                    if (instruction.opcode == .inc) value +% 1 else value -% 1,
                    byte_mode,
                );
                try self.writeOperand(first, result, byte_mode);
                self.setZeroSign(result, byte_mode);
            },
            .jmp => return @as(usize, self.readOperand(first, false)),
            .xor, .and_, .or_, .test_ => {
                const a = self.readOperand(first, byte_mode);
                const b = self.readOperand(second, byte_mode);
                const result = self.maskWidth(switch (instruction.opcode) {
                    .xor => a ^ b,
                    .and_, .test_ => a & b,
                    .or_ => a | b,
                    else => unreachable,
                }, byte_mode);
                if (instruction.opcode != .test_)
                    try self.writeOperand(first, result, byte_mode);
                self.setZeroSign(result, byte_mode);
            },
            .js => return self.conditionalJump(first, self.flags & flag_sign != 0),
            .jns => return self.conditionalJump(first, self.flags & flag_sign == 0),
            .jb => return self.conditionalJump(first, self.flags & flag_carry != 0),
            .jbe => return self.conditionalJump(first, self.flags & (flag_carry | flag_zero) != 0),
            .ja => return self.conditionalJump(first, self.flags & (flag_carry | flag_zero) == 0),
            .jae => return self.conditionalJump(first, self.flags & flag_carry == 0),
            .push => self.push(self.readOperand(first, false)),
            .pop => try self.writeOperand(first, self.pop(), false),
            .call => {
                self.push(@intCast(instruction_pointer));
                return @as(usize, self.readOperand(first, false));
            },
            .ret => {
                if (self.regs[7] >= memory_size) return std.math.maxInt(usize);
                return @as(usize, self.pop());
            },
            .not => try self.writeOperand(
                first,
                self.maskWidth(~self.readOperand(first, byte_mode), byte_mode),
                byte_mode,
            ),
            .shl, .shr, .sar => try self.shift(
                instruction.opcode,
                first,
                self.readOperand(second, byte_mode),
                byte_mode,
            ),
            .neg => {
                const result = self.maskWidth(0 -% self.readOperand(first, byte_mode), byte_mode);
                try self.writeOperand(first, result, byte_mode);
                self.flags = if (result == 0)
                    flag_zero
                else
                    flag_carry | (result & self.signBit(byte_mode));
            },
            .pusha => {
                const registers = self.regs;
                for (registers) |value| self.push(value);
            },
            .popa => {
                var stack = self.regs[7];
                var index: usize = 8;
                while (index != 0) {
                    index -= 1;
                    self.regs[index] = self.readMemory(stack, false);
                    stack +%= 4;
                }
            },
            .pushf => self.push(self.flags),
            .popf => self.flags = self.pop(),
            .movzx => try self.writeOperand(first, self.readOperand(second, true) & 0xff, false),
            .movsx => {
                const signed: i8 = @bitCast(@as(u8, @truncate(self.readOperand(second, true))));
                try self.writeOperand(first, @bitCast(@as(i32, signed)), false);
            },
            .xchg => {
                const a = self.readOperand(first, byte_mode);
                const b = self.readOperand(second, byte_mode);
                try self.writeOperand(first, b, byte_mode);
                try self.writeOperand(second, a, byte_mode);
            },
            .mul => try self.writeOperand(
                first,
                self.maskWidth(
                    self.readOperand(first, byte_mode) *% self.readOperand(second, byte_mode),
                    byte_mode,
                ),
                byte_mode,
            ),
            .div => {
                const divisor = self.readOperand(second, byte_mode);
                if (divisor != 0)
                    try self.writeOperand(
                        first,
                        self.readOperand(first, byte_mode) / divisor,
                        byte_mode,
                    );
            },
            .adc, .sbb => {
                const a = self.readOperand(first, byte_mode);
                const b = self.readOperand(second, byte_mode);
                const carry: u32 = @intFromBool(self.flags & flag_carry != 0);
                const result = self.maskWidth(if (instruction.opcode == .adc)
                    a +% b +% carry
                else
                    a -% b -% carry, byte_mode);
                try self.writeOperand(first, result, byte_mode);
                if (instruction.opcode == .adc)
                    self.setAddFlags(a, b, carry, result, byte_mode)
                else
                    self.setSubFlags(a, b, carry, byte_mode);
            },
            .print => {},
        }
        return null;
    }

    fn conditionalJump(self: *const Vm, operand: *const Operand, condition: bool) ?usize {
        return if (condition) @as(usize, self.readOperand(operand, false)) else null;
    }

    fn readOperand(self: *const Vm, operand: *const Operand, byte_mode: bool) u32 {
        return switch (operand.*) {
            .register => |index| self.maskWidth(self.regs[index], byte_mode),
            .immediate => |value| self.maskWidth(value, byte_mode),
            .register_indirect => |index| self.readMemory(self.regs[index], byte_mode),
            .indexed => |value| self.readMemory(value.base +% self.regs[value.register], byte_mode),
            .absolute => |address| self.readMemory(address, byte_mode),
        };
    }

    fn writeOperand(
        self: *Vm,
        operand: *const Operand,
        value: u32,
        byte_mode: bool,
    ) Error!void {
        switch (operand.*) {
            .register => |index| if (byte_mode) {
                self.regs[index] = (self.regs[index] & 0xffff_ff00) | (value & 0xff);
            } else {
                self.regs[index] = value;
            },
            .register_indirect => |index| self.writeMemory(self.regs[index], value, byte_mode),
            .indexed => |item| self.writeMemory(
                item.base +% self.regs[item.register],
                value,
                byte_mode,
            ),
            .absolute => |address| self.writeMemory(address, value, byte_mode),
            .immediate => return error.InvalidRar29Stream,
        }
    }

    fn readMemory(self: *const Vm, raw_address: u32, byte_mode: bool) u32 {
        const address = raw_address & memory_mask;
        return if (byte_mode) self.memory[address] else self.readU32(address);
    }

    fn writeMemory(self: *Vm, raw_address: u32, value: u32, byte_mode: bool) void {
        const address = raw_address & memory_mask;
        if (byte_mode)
            self.memory[address] = @truncate(value)
        else
            writeU32(self.memory, address, value);
    }

    fn readU32(self: *const Vm, raw_address: usize) u32 {
        const address: u32 = @truncate(raw_address);
        var bytes: [4]u8 = undefined;
        for (&bytes, 0..) |*byte, offset|
            byte.* = self.memory[(address +% @as(u32, @intCast(offset))) & memory_mask];
        return std.mem.readInt(u32, &bytes, .little);
    }

    fn push(self: *Vm, value: u32) void {
        self.regs[7] -%= 4;
        self.writeMemory(self.regs[7], value, false);
    }

    fn pop(self: *Vm) u32 {
        const value = self.readMemory(self.regs[7], false);
        self.regs[7] +%= 4;
        return value;
    }

    fn shift(
        self: *Vm,
        opcode: Opcode,
        destination: *const Operand,
        raw_count: u32,
        byte_mode: bool,
    ) Error!void {
        if (raw_count == 0) return;
        const width: u32 = if (byte_mode) 8 else 32;
        const count = @min(raw_count, width);
        const value = self.readOperand(destination, byte_mode);
        const result: u32 = switch (opcode) {
            .shl => if (count == width) 0 else value << @intCast(count),
            .shr => if (count == width) 0 else value >> @intCast(count),
            .sar => if (byte_mode)
                if (count >= 8)
                    if (value & 0x80 != 0) 0xff else 0
                else blk: {
                    const signed: i8 = @bitCast(@as(u8, @truncate(value)));
                    break :blk @as(u8, @bitCast(signed >> @intCast(count)));
                }
            else if (count >= 32)
                if (value & 0x8000_0000 != 0) std.math.maxInt(u32) else 0
            else blk: {
                const signed: i32 = @bitCast(value);
                break :blk @bitCast(signed >> @intCast(count));
            },
            else => unreachable,
        };
        const carry = switch (opcode) {
            .shl => value & (@as(u32, 1) << @intCast(width - count)) != 0,
            .shr, .sar => value & (@as(u32, 1) << @intCast(count - 1)) != 0,
            else => unreachable,
        };
        const narrowed = self.maskWidth(result, byte_mode);
        try self.writeOperand(destination, narrowed, byte_mode);
        self.setZeroSignCarry(narrowed, carry, byte_mode);
    }

    fn setAddFlags(
        self: *Vm,
        a: u32,
        b: u32,
        carry: u32,
        result: u32,
        byte_mode: bool,
    ) void {
        const mask = @as(u64, self.valueMask(byte_mode));
        const sum = (@as(u64, a) & mask) + (@as(u64, b) & mask) + carry;
        self.setZeroSignCarry(result, sum > mask, byte_mode);
    }

    fn setSubFlags(self: *Vm, a: u32, b: u32, borrow: u32, byte_mode: bool) void {
        const mask = @as(u64, self.valueMask(byte_mode));
        const minuend = @as(u64, a) & mask;
        const subtrahend = (@as(u64, b) & mask) + borrow;
        const result = self.maskWidth(
            @as(u32, @truncate(minuend)) -% @as(u32, @truncate(subtrahend)),
            byte_mode,
        );
        self.setZeroSignCarry(result, minuend < subtrahend, byte_mode);
    }

    fn setZeroSign(self: *Vm, result: u32, byte_mode: bool) void {
        self.flags = if (result == 0) flag_zero else result & self.signBit(byte_mode);
    }

    fn setZeroSignCarry(self: *Vm, result: u32, carry: bool, byte_mode: bool) void {
        self.setZeroSign(result, byte_mode);
        if (carry) self.flags |= flag_carry;
    }

    fn maskWidth(_: *const Vm, value: u32, byte_mode: bool) u32 {
        return value & (if (byte_mode) @as(u32, 0xff) else std.math.maxInt(u32));
    }

    fn valueMask(_: *const Vm, byte_mode: bool) u32 {
        return if (byte_mode) 0xff else std.math.maxInt(u32);
    }

    fn signBit(_: *const Vm, byte_mode: bool) u32 {
        return if (byte_mode) 0x80 else flag_sign;
    }
};

fn writeU32(memory: []u8, raw_address: usize, value: u32) void {
    const address: u32 = @truncate(raw_address);
    var bytes: [4]u8 = undefined;
    std.mem.writeInt(u32, &bytes, value, .little);
    for (bytes, 0..) |byte, offset|
        memory[(address +% @as(u32, @intCast(offset))) & memory_mask] = byte;
}

const BitReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn remaining(self: BitReader) usize {
        return self.input.len * 8 - self.bit_offset;
    }

    fn read(self: *BitReader, count: u8) Error!u32 {
        if (count > 32 or self.remaining() < count) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |_| {
            const byte = self.input[self.bit_offset / 8];
            const bit = (byte >> @intCast(7 - self.bit_offset % 8)) & 1;
            value = value *% 2 | bit;
            self.bit_offset += 1;
        }
        return value;
    }

    fn readVmNumber(self: *BitReader) Error!u32 {
        return switch (try self.read(2)) {
            0 => self.read(4),
            1 => blk: {
                const high = try self.read(8);
                break :blk if (high >= 16)
                    high
                else
                    0xffff_ff00 | (high << 4) | try self.read(4);
            },
            2 => self.read(16),
            3 => self.read(32),
            else => unreachable,
        };
    }
};

test "RAR VM rejects invalid bytecode checksum" {
    try std.testing.expectError(
        error.InvalidRar29Stream,
        Program.parse(std.testing.allocator, &.{ 0x12, 0x34 }),
    );
}

test "RAR VM executes arithmetic and byte memory writes" {
    const instructions = [_]Instruction{
        .{
            .opcode = .mov,
            .byte_mode = false,
            .operands = .{ .{ .register = 0 }, .{ .immediate = 7 } },
            .operand_count = 2,
        },
        .{
            .opcode = .add,
            .byte_mode = false,
            .operands = .{ .{ .register = 0 }, .{ .immediate = 5 } },
            .operand_count = 2,
        },
        .{
            .opcode = .mov,
            .byte_mode = true,
            .operands = .{ .{ .absolute = 0 }, .{ .register = 0 } },
            .operand_count = 2,
        },
        .{
            .opcode = .ret,
            .byte_mode = false,
            .operand_count = 0,
        },
    };
    const program = Program{
        .allocator = std.testing.allocator,
        .static_data = &.{},
        .instructions = @constCast(&instructions),
    };
    var result = try program.execute(
        std.testing.allocator,
        &.{0},
        @splat(0),
        &.{},
        0,
        0,
        32,
    );
    defer result.deinit();
    try std.testing.expectEqualSlices(u8, &.{12}, result.output);
}

test "RAR VM enforces its instruction budget" {
    const instructions = [_]Instruction{.{
        .opcode = .jmp,
        .byte_mode = false,
        .operands = .{ .{ .immediate = 0 }, undefined },
        .operand_count = 1,
    }};
    const program = Program{
        .allocator = std.testing.allocator,
        .static_data = &.{},
        .instructions = @constCast(&instructions),
    };
    try std.testing.expectError(
        error.InvalidRar29Stream,
        program.execute(
            std.testing.allocator,
            &.{0},
            @splat(0),
            &.{},
            0,
            0,
            32,
        ),
    );
}
