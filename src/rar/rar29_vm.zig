const std = @import("std");
const checksum = @import("../checksum.zig");
const core = @import("../core.zig");
const rar_vm = @import("rar_vm.zig");

pub const Error = core.Error || std.mem.Allocator.Error || error{
    InvalidRar29Stream,
    UnsupportedRar29Filter,
};

pub const default_max_instructions = rar_vm.default_max_instructions;

const max_code_size: usize = 64 * 1024;
const max_programs: usize = 8192;
const max_filters: usize = 8192;
const max_delta_channels: usize = 1024;
const vm_fixed_global_size: usize = 64;
const vm_max_user_global_size: usize = 0x2000 - vm_fixed_global_size;

const StandardFilter = enum {
    e8,
    e8e9,
    itanium,
    delta,
    rgb,
    audio,
};

const Program = struct {
    kind: union(enum) {
        standard: StandardFilter,
        generic: rar_vm.Program,
    },
    block_size: usize,
    exec_count: u32 = 0,
    globals: std.ArrayList(u8) = .empty,

    fn deinit(self: *Program, allocator: std.mem.Allocator) void {
        switch (self.kind) {
            .standard => {},
            .generic => |*program| program.deinit(),
        }
        self.globals.deinit(allocator);
        self.* = undefined;
    }
};

const Filter = struct {
    program: usize,
    start: usize,
    size: usize,
    regs: [7]u32,
    global_data: std.ArrayList(u8) = .empty,

    fn deinit(self: *Filter, allocator: std.mem.Allocator) void {
        self.global_data.deinit(allocator);
        self.* = undefined;
    }
};

pub const State = struct {
    allocator: std.mem.Allocator,
    programs: std.ArrayList(Program) = .empty,
    filters: std.ArrayList(Filter) = .empty,
    last_filter: usize = 0,
    max_instructions: usize,

    pub fn init(allocator: std.mem.Allocator, max_instructions: usize) State {
        return .{ .allocator = allocator, .max_instructions = max_instructions };
    }

    pub fn deinit(self: *State) void {
        self.clearFilters();
        self.clearPrograms();
        self.programs.deinit(self.allocator);
        self.filters.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn parseRecord(
        self: *State,
        first_byte: u8,
        data: []const u8,
        current_position: usize,
    ) Error!void {
        var bits = RecordReader{ .input = data };
        const program_index = if (first_byte & 0x80 != 0) blk: {
            const selector = try bits.readEncodedU32();
            if (selector == 0) {
                self.clearFilters();
                self.clearPrograms();
                break :blk 0;
            }
            break :blk @as(usize, selector - 1);
        } else self.last_filter;
        if (program_index > self.programs.items.len) return error.InvalidRar29Stream;
        self.last_filter = program_index;
        const new_program = program_index == self.programs.items.len;

        var block_start = @as(usize, try bits.readEncodedU32());
        if (first_byte & 0x40 != 0)
            block_start = std.math.add(usize, block_start, 258) catch
                return error.IntegerOverflow;
        block_start = std.math.add(usize, current_position, block_start) catch
            return error.IntegerOverflow;

        var block_size = if (program_index < self.programs.items.len)
            self.programs.items[program_index].block_size
        else
            0;
        if (first_byte & 0x20 != 0)
            block_size = @as(usize, try bits.readEncodedU32());

        var regs: [7]u32 = @splat(0);
        regs[3] = 0x3c000;
        regs[4] = @truncate(block_size);
        if (!new_program) regs[5] = self.programs.items[program_index].exec_count;
        if (first_byte & 0x10 != 0) {
            const mask = try bits.read(7);
            for (&regs, 0..) |*reg, index| {
                if (mask & (@as(u32, 1) << @intCast(index)) != 0) {
                    reg.* = try bits.readEncodedU32();
                }
            }
        }

        if (new_program) {
            if (self.programs.items.len == max_programs) return error.InvalidRar29Stream;
            const code_size = @as(usize, try bits.readEncodedU32());
            if (code_size == 0 or code_size > max_code_size)
                return error.InvalidRar29Stream;
            const code = try self.allocator.alloc(u8, code_size);
            defer self.allocator.free(code);
            for (code) |*byte| byte.* = @intCast(try bits.read(8));
            if (identifyStandardFilter(code)) |filter| {
                try self.programs.append(self.allocator, .{
                    .kind = .{ .standard = filter },
                    .block_size = block_size,
                });
            } else {
                var generic = try rar_vm.Program.parse(self.allocator, code);
                self.programs.append(self.allocator, .{
                    .kind = .{ .generic = generic },
                    .block_size = block_size,
                }) catch |err| {
                    generic.deinit();
                    return err;
                };
            }
        } else {
            const program = &self.programs.items[program_index];
            program.exec_count +%= 1;
            program.block_size = block_size;
        }

        var global_data: std.ArrayList(u8) = .empty;
        errdefer global_data.deinit(self.allocator);
        if (first_byte & 0x08 != 0) {
            const global_size = @as(usize, try bits.readEncodedU32());
            if (global_size > vm_max_user_global_size) return error.InvalidRar29Stream;
            try global_data.ensureTotalCapacity(self.allocator, global_size);
            for (0..global_size) |_|
                global_data.appendAssumeCapacity(@intCast(try bits.read(8)));
        }

        if (self.filters.items.len == max_filters) return error.InvalidRar29Stream;
        try self.filters.append(self.allocator, .{
            .program = program_index,
            .start = block_start,
            .size = block_size,
            .regs = regs,
            .global_data = global_data,
        });
    }

    pub fn apply(self: *State, output: []u8) Error!void {
        var filtered: std.ArrayList(u8) = .empty;
        defer filtered.deinit(self.allocator);
        var raw_position: usize = 0;
        var filter_index: usize = 0;
        while (filter_index < self.filters.items.len) {
            const first_filter = &self.filters.items[filter_index];
            const raw_end = std.math.add(usize, first_filter.start, first_filter.size) catch
                return error.IntegerOverflow;
            if (raw_end > output.len) return error.SizeMismatch;
            if (first_filter.start < raw_position) {
                filter_index += 1;
                continue;
            }
            try filtered.appendSlice(
                self.allocator,
                output[raw_position..first_filter.start],
            );
            var block = std.ArrayList(u8).fromOwnedSlice(
                try self.allocator.dupe(u8, output[first_filter.start..raw_end]),
            );
            defer block.deinit(self.allocator);
            const file_offset = filtered.items.len;
            const chain_start = first_filter.start;
            while (true) {
                const filter = &self.filters.items[filter_index];
                if (filter.program >= self.programs.items.len)
                    return error.InvalidRar29Stream;
                const program = &self.programs.items[filter.program];
                switch (program.kind) {
                    .standard => |standard| try applyStandardFilter(
                        self.allocator,
                        standard,
                        block.items,
                        @truncate(file_offset),
                        &filter.regs,
                    ),
                    .generic => |generic| {
                        var explicit_globals: std.ArrayList(u8) = .empty;
                        defer explicit_globals.deinit(self.allocator);
                        const globals = if (filter.global_data.items.len != 0) blk: {
                            try explicit_globals.appendNTimes(
                                self.allocator,
                                0,
                                vm_fixed_global_size,
                            );
                            try explicit_globals.appendSlice(
                                self.allocator,
                                filter.global_data.items,
                            );
                            break :blk explicit_globals.items;
                        } else program.globals.items;
                        var result = try generic.execute(
                            self.allocator,
                            block.items,
                            filter.regs,
                            globals,
                            file_offset,
                            program.exec_count,
                            self.max_instructions,
                        );
                        defer result.deinit();
                        block.clearRetainingCapacity();
                        try block.appendSlice(self.allocator, result.output);
                        program.globals.clearRetainingCapacity();
                        try program.globals.appendSlice(self.allocator, result.globals);
                    },
                }
                filter_index += 1;
                if (filter_index == self.filters.items.len) break;
                const next = &self.filters.items[filter_index];
                if (next.start != chain_start or next.size != block.items.len) break;
            }
            try filtered.appendSlice(self.allocator, block.items);
            raw_position = raw_end;
        }
        try filtered.appendSlice(self.allocator, output[raw_position..]);
        if (filtered.items.len != output.len) return error.SizeMismatch;
        @memcpy(output, filtered.items);
    }

    fn clearFilters(self: *State) void {
        for (self.filters.items) |*filter| filter.deinit(self.allocator);
        self.filters.clearRetainingCapacity();
    }

    fn clearPrograms(self: *State) void {
        for (self.programs.items) |*program| program.deinit(self.allocator);
        self.programs.clearRetainingCapacity();
    }
};

const RecordReader = struct {
    input: []const u8,
    bit_offset: usize = 0,

    fn read(self: *RecordReader, count: u8) Error!u32 {
        if (count > 32) return error.InvalidRar29Stream;
        const total_bits = std.math.mul(usize, self.input.len, 8) catch
            return error.IntegerOverflow;
        if (self.bit_offset > total_bits or count > total_bits - self.bit_offset)
            return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..count) |index| {
            const bit = self.bit_offset + index;
            value = (value << 1) |
                ((self.input[bit / 8] >> @intCast(7 - bit % 8)) & 1);
        }
        self.bit_offset += count;
        return value;
    }

    fn readEncodedU32(self: *RecordReader) Error!u32 {
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
            3 => (try self.read(16) << 16) | try self.read(16),
            else => unreachable,
        };
    }
};

fn identifyStandardFilter(code: []const u8) ?StandardFilter {
    var xor: u8 = 0;
    for (code) |byte| xor ^= byte;
    if (xor != 0) return null;
    return switch (code.len) {
        53 => if (checksum.crc32(code) == 0xad57_6887) .e8 else null,
        57 => if (checksum.crc32(code) == 0x3cd7_e57e) .e8e9 else null,
        120 => if (checksum.crc32(code) == 0x3769_893f) .itanium else null,
        29 => if (checksum.crc32(code) == 0x0e06_077d) .delta else null,
        149 => if (checksum.crc32(code) == 0x1c2c_5dc8) .rgb else null,
        216 => if (checksum.crc32(code) == 0xbc85_e701) .audio else null,
        else => null,
    };
}

fn applyStandardFilter(
    allocator: std.mem.Allocator,
    filter: StandardFilter,
    data: []u8,
    file_offset: u32,
    regs: *const [7]u32,
) Error!void {
    switch (filter) {
        .e8 => decodeE8E9(data, file_offset, false),
        .e8e9 => decodeE8E9(data, file_offset, true),
        .itanium => decodeItanium(data, file_offset),
        .delta => {
            const channels = @as(usize, regs[0]);
            if (channels == 0 or channels > max_delta_channels)
                return error.InvalidRar29Stream;
            const scratch = try allocator.alloc(u8, data.len);
            defer allocator.free(scratch);
            try decodeDelta(data, scratch, channels);
            @memcpy(data, scratch);
        },
        .rgb => {
            if (regs[0] < 3 or regs[1] > 2) return error.InvalidRar29Stream;
            const scratch = try allocator.alloc(u8, data.len);
            defer allocator.free(scratch);
            try decodeRgb(data, scratch, @as(usize, regs[0] - 3), @as(usize, regs[1]));
            @memcpy(data, scratch);
        },
        .audio => {
            const channels = @as(usize, regs[0]);
            if (channels == 0 or channels > max_delta_channels)
                return error.InvalidRar29Stream;
            const scratch = try allocator.alloc(u8, data.len);
            defer allocator.free(scratch);
            try decodeAudio(data, scratch, channels);
            @memcpy(data, scratch);
        },
    }
}

fn decodeE8E9(data: []u8, file_offset: u32, include_e9: bool) void {
    if (data.len <= 4) return;
    const compare_mask: u8 = if (include_e9) 0xfe else 0xff;
    var position: usize = 0;
    while (position < data.len - 4) {
        position += 1;
        if (data[position - 1] & compare_mask != 0xe8) continue;
        const offset = file_offset +% @as(u32, @truncate(position));
        const address = std.mem.readInt(u32, data[position..][0..4], .little);
        const decoded = if (address < 0x0100_0000)
            address -% offset
        else if (address & 0x8000_0000 != 0 and
            address +% offset & 0x8000_0000 == 0)
            address +% 0x0100_0000
        else {
            position += 4;
            continue;
        };
        std.mem.writeInt(u32, data[position..][0..4], decoded, .little);
        position += 4;
    }
}

fn decodeItanium(data: []u8, file_offset: u32) void {
    if (data.len <= 21) return;
    const base_offset = file_offset >> 4;
    const block_count = std.math.divCeil(usize, data.len - 21, 16) catch unreachable;
    for (0..block_count) |block| {
        const position = block * 16;
        const current_offset = base_offset +% @as(u32, @truncate(block));
        var mask: u32 = (@as(u32, 0x334b_0000) >> @intCast(data[position] & 0x1e)) & 3;
        if (mask == 0) continue;
        mask += 1;
        while (mask <= 4) : (mask += 1) {
            const instruction = position + @as(usize, mask) * 5 - 8;
            if ((data[instruction + 3] >> @intCast(mask)) & 15 != 5) continue;
            const raw = std.mem.readInt(u32, data[instruction..][0..4], .little);
            const shift: u5 = @intCast(mask);
            const value = (raw >> shift) -% current_offset & 0x000f_ffff;
            const decoded = (raw & ~(@as(u32, 0x000f_ffff) << shift)) | (value << shift);
            std.mem.writeInt(u32, data[instruction..][0..4], decoded, .little);
        }
    }
}

fn decodeDelta(encoded: []const u8, output: []u8, channels: usize) Error!void {
    if (encoded.len != output.len) return error.SizeMismatch;
    var source: usize = 0;
    for (0..channels) |channel| {
        var previous: u8 = 0;
        var destination = channel;
        while (destination < output.len) : (destination += channels) {
            if (source == encoded.len) return error.TruncatedFrame;
            previous -%= encoded[source];
            source += 1;
            output[destination] = previous;
        }
    }
    if (source != encoded.len) return error.InvalidRar29Stream;
}

fn decodeRgb(encoded: []const u8, output: []u8, width: usize, red_position: usize) Error!void {
    if (encoded.len != output.len) return error.SizeMismatch;
    if (encoded.len < 3 or width == 0 or width % 3 != 0 or
        width > encoded.len or red_position > 2)
        return error.InvalidRar29Stream;
    var source: usize = 0;
    for (0..3) |channel| {
        var previous: u8 = 0;
        var destination = channel;
        while (destination < output.len) : (destination += 3) {
            const predicted = if (destination >= width + 3)
                rgbPredict(previous, output[destination - width], output[destination - width - 3])
            else
                previous;
            if (source == encoded.len) return error.TruncatedFrame;
            previous = predicted -% encoded[source];
            source += 1;
            output[destination] = previous;
        }
    }
    if (source != encoded.len) return error.InvalidRar29Stream;
    var position = red_position;
    while (position < output.len - 2) : (position += 3) {
        const green = output[position + 1];
        output[position] +%= green;
        output[position + 2] +%= green;
    }
}

fn rgbPredict(previous: u8, upper: u8, upper_left: u8) u8 {
    const predicted = @as(i32, previous) + @as(i32, upper) - @as(i32, upper_left);
    const distance_previous = @abs(predicted - @as(i32, previous));
    const distance_upper = @abs(predicted - @as(i32, upper));
    const distance_upper_left = @abs(predicted - @as(i32, upper_left));
    if (distance_previous <= distance_upper and distance_previous <= distance_upper_left)
        return previous;
    return if (distance_upper <= distance_upper_left) upper else upper_left;
}

fn decodeAudio(encoded: []const u8, output: []u8, channels: usize) Error!void {
    if (encoded.len != output.len) return error.SizeMismatch;
    var source: usize = 0;
    for (0..channels) |channel| {
        var previous_byte: u32 = 0;
        var previous_delta: i32 = 0;
        var delta_1: i32 = 0;
        var delta_2: i32 = 0;
        var coefficient_1: i32 = 0;
        var coefficient_2: i32 = 0;
        var coefficient_3: i32 = 0;
        var differences: [7]u32 = @splat(0);
        var byte_count: usize = 0;
        var destination = channel;
        while (destination < output.len) : (destination += channels) {
            const delta_3 = delta_2;
            delta_2 = previous_delta - delta_1;
            delta_1 = previous_delta;
            const predicted = (8 * @as(i32, @intCast(previous_byte)) +
                coefficient_1 * delta_1 + coefficient_2 * delta_2 +
                coefficient_3 * delta_3) >> 3 & 0xff;
            if (source == encoded.len) return error.TruncatedFrame;
            const encoded_byte = encoded[source];
            source += 1;
            const decoded: u8 = @as(u8, @intCast(predicted)) -% encoded_byte;
            output[destination] = decoded;
            previous_delta = @as(i8, @bitCast(decoded -% @as(u8, @truncate(previous_byte))));
            previous_byte = decoded;
            const difference = @as(i32, @as(i8, @bitCast(encoded_byte))) << 3;
            differences[0] +%= @abs(difference);
            differences[1] +%= @abs(difference - delta_1);
            differences[2] +%= @abs(difference + delta_1);
            differences[3] +%= @abs(difference - delta_2);
            differences[4] +%= @abs(difference + delta_2);
            differences[5] +%= @abs(difference - delta_3);
            differences[6] +%= @abs(difference + delta_3);
            if (byte_count & 0x1f == 0) {
                var minimum = differences[0];
                var minimum_index: usize = 0;
                differences[0] = 0;
                for (differences[1..], 1..) |*value, index| {
                    if (value.* < minimum) {
                        minimum = value.*;
                        minimum_index = index;
                    }
                    value.* = 0;
                }
                switch (minimum_index) {
                    1 => if (coefficient_1 >= -16) {
                        coefficient_1 -= 1;
                    },
                    2 => if (coefficient_1 < 16) {
                        coefficient_1 += 1;
                    },
                    3 => if (coefficient_2 >= -16) {
                        coefficient_2 -= 1;
                    },
                    4 => if (coefficient_2 < 16) {
                        coefficient_2 += 1;
                    },
                    5 => if (coefficient_3 >= -16) {
                        coefficient_3 -= 1;
                    },
                    6 => if (coefficient_3 < 16) {
                        coefficient_3 += 1;
                    },
                    else => {},
                }
            }
            byte_count += 1;
        }
    }
    if (source != encoded.len) return error.InvalidRar29Stream;
}

test "RAR29 standard DELTA filter reconstructs interleaved channels" {
    const encoded = [_]u8{ 246, 255, 236, 254, 226, 253 };
    var output: [encoded.len]u8 = undefined;
    try decodeDelta(&encoded, &output, 3);
    try std.testing.expectEqualSlices(u8, &.{ 10, 20, 30, 11, 22, 33 }, &output);
}

test "RAR29 VM record reader decodes every integer width" {
    var narrow = RecordReader{ .input = &.{0x0f} };
    try std.testing.expectEqual(@as(u32, 3), try narrow.readEncodedU32());

    var byte = RecordReader{ .input = &.{ 0x68, 0x80 } };
    try std.testing.expectEqual(@as(u32, 0xa2), try byte.readEncodedU32());

    var short = RecordReader{ .input = &.{ 0x84, 0x8d, 0x00 } };
    try std.testing.expectEqual(@as(u32, 0x1234), try short.readEncodedU32());

    var word = RecordReader{ .input = &.{ 0xc4, 0x8d, 0x15, 0x9e, 0x00 } };
    try std.testing.expectEqual(@as(u32, 0x1234_5678), try word.readEncodedU32());
}

test "RAR29 filter scheduler chains records covering one block" {
    var state = State.init(std.testing.allocator, 1000);
    defer state.deinit();
    try state.programs.append(std.testing.allocator, .{
        .kind = .{ .standard = .delta },
        .block_size = 2,
    });
    try state.filters.append(std.testing.allocator, .{
        .program = 0,
        .start = 0,
        .size = 2,
        .regs = .{ 1, 0, 0, 0, 2, 0, 0 },
    });
    try state.filters.append(std.testing.allocator, .{
        .program = 0,
        .start = 0,
        .size = 2,
        .regs = .{ 1, 0, 0, 0, 2, 0, 0 },
    });
    var bytes = [_]u8{ 255, 255 };
    try state.apply(&bytes);
    try std.testing.expectEqualSlices(u8, &.{ 255, 253 }, &bytes);
}
