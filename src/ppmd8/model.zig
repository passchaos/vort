const std = @import("std");

pub const min_order: u8 = 2;
pub const max_order: u8 = 16;
pub const min_memory_size: u32 = 2 * 1024;
pub const max_memory_size: u32 = std.math.maxInt(u32);

pub const Error = std.mem.Allocator.Error || error{
    InvalidPpmdOrder,
    InvalidPpmdMemorySize,
};

pub const RestoreMethod = enum(u1) {
    restart = 0,
    cut_off = 1,
};

pub const int_bits: u5 = 7;
pub const period_bits: u5 = 7;
pub const bin_scale: u32 = 1 << (int_bits + period_bits);
pub const max_frequency: u8 = 124;
pub const unit_size: usize = 12;

const num_indexes: usize = 38;
const empty_node: u32 = std.math.maxInt(u32);
const flag_rescaled: u8 = 1 << 2;
const flag_prev_high: u8 = 1 << 4;
const exp_escape = [16]u8{ 25, 14, 9, 7, 5, 5, 4, 4, 4, 3, 3, 3, 2, 2, 2, 2 };
const init_bin_escape = [8]u16{ 0x3cdd, 0x1f3f, 0x59bf, 0x48f3, 0x64a1, 0x5abc, 0x6632, 0x6051 };

pub fn expEscape(index: u32) u8 {
    return exp_escape[index];
}

pub const SeeSource = union(enum) {
    dummy,
    table: struct { row: usize, column: usize },
};

pub const Offset = extern struct {
    value: u32 = 0,

    pub const null_offset: Offset = .{};

    pub fn init(value: usize) Offset {
        return .{ .value = @intCast(value) };
    }

    pub fn isNull(self: Offset) bool {
        return self.value == 0;
    }

    pub fn isValidFor(self: Offset, memory_len: usize, comptime T: type) bool {
        if (self.isNull()) return false;
        const start: usize = self.value;
        return start <= memory_len and @sizeOf(T) <= memory_len - start and
            start % @alignOf(T) == 0;
    }
};

pub const See = extern struct {
    summ: u16 = 0,
    shift: u8 = 0,
    count: u8 = 0,

    pub fn update(self: *See) void {
        if (self.shift < period_bits) {
            self.count -%= 1;
            if (self.count == 0) {
                self.summ = @truncate(@as(u32, self.summ) << 1);
                const old_shift = self.shift;
                self.shift += 1;
                self.count = @as(u8, 3) << @intCast(old_shift);
            }
        }
    }
};

pub const State = extern struct {
    symbol: u8,
    freq: u8,
    successor_0: u16,
    successor_1: u16,

    pub fn successor(self: *const State) Offset {
        return .{ .value = @as(u32, self.successor_0) | (@as(u32, self.successor_1) << 16) };
    }

    pub fn setSuccessor(self: *State, value: Offset) void {
        self.successor_0 = @truncate(value.value);
        self.successor_1 = @truncate(value.value >> 16);
    }
};

pub const State2 = extern struct {
    symbol: u8,
    freq: u8,
};

pub const State4 = extern struct {
    successor_0: u16,
    successor_1: u16,

    pub fn successor(self: *const State4) Offset {
        return .{ .value = @as(u32, self.successor_0) | (@as(u32, self.successor_1) << 16) };
    }

    pub fn setSuccessor(self: *State4, value: Offset) void {
        self.successor_0 = @truncate(value.value);
        self.successor_1 = @truncate(value.value >> 16);
    }
};

pub const Union2 = extern union {
    summ_freq: u16,
    state: State2,
};

pub const Union4 = extern union {
    stats: Offset,
    state: State4,
};

pub const Context = extern struct {
    num_stats: u8,
    flags: u8,
    union2: Union2,
    union4: Union4,
    suffix: Offset,
};

const Node = extern struct {
    stamp: u32,
    next: Offset,
    units: u32,
};

pub const Model = struct {
    allocator: std.mem.Allocator,
    memory: []align(8) u8,
    memory_size: u32,
    align_offset: u2,
    max_order_value: u8,
    restore_method: RestoreMethod,

    min_context: Offset = .null_offset,
    max_context: Offset = .null_offset,
    found_state: Offset = .null_offset,
    order_fall: u32 = 0,
    init_esc: u32 = 0,
    prev_success: u32 = 0,
    run_length: i32 = 0,
    init_rl: i32 = 0,

    lo_unit: usize = 0,
    hi_unit: usize = 0,
    text: usize = 0,
    units_start: usize = 0,
    glue_count: u32 = 0,

    index2units: [40]u8 = @splat(0),
    units2index: [128]u8 = @splat(0),
    free_list: [num_indexes]Offset = @splat(.null_offset),
    stamps: [num_indexes]u32 = @splat(0),
    ns2bs_index: [256]u8 = @splat(0),
    ns2index: [260]u8 = @splat(0),
    dummy_see: See = .{},
    see: [24][32]See = @splat(@splat(.{})),
    bin_summ: [25][64]u16 = @splat(@splat(0)),

    pub fn init(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
        restore_method: RestoreMethod,
    ) Error!Model {
        if (order < min_order or order > max_order) return error.InvalidPpmdOrder;
        if (memory_size < min_memory_size) return error.InvalidPpmdMemorySize;
        const align_offset: u2 = @intCast((@as(u32, 4) -% memory_size) & 3);
        const allocation_size = @as(usize, memory_size) + align_offset;
        const memory = try allocator.alignedAlloc(u8, .@"8", allocation_size);
        errdefer allocator.free(memory);
        @memset(memory, 0);

        var result = Model{
            .allocator = allocator,
            .memory = memory,
            .memory_size = memory_size,
            .align_offset = align_offset,
            .max_order_value = order,
            .restore_method = restore_method,
        };
        result.initializeIndexes();
        result.restart();
        return result;
    }

    pub fn deinit(self: *Model) void {
        self.allocator.free(self.memory);
        self.* = undefined;
    }

    fn initializeIndexes(self: *Model) void {
        var unit_count: usize = 0;
        for (0..num_indexes) |index| {
            const step: usize = if (index >= 12) 4 else (index >> 2) + 1;
            for (0..step) |_| {
                self.units2index[unit_count] = @intCast(index);
                unit_count += 1;
            }
            self.index2units[index] = @intCast(unit_count);
        }

        self.ns2bs_index[0] = 0;
        self.ns2bs_index[1] = 2;
        @memset(self.ns2bs_index[2..11], 4);
        @memset(self.ns2bs_index[11..], 6);

        for (0..5) |index| self.ns2index[index] = @intCast(index);
        var next_index: usize = 5;
        var remaining: usize = 1;
        for (5..260) |stats_count| {
            self.ns2index[stats_count] = @intCast(next_index);
            remaining -= 1;
            if (remaining == 0) {
                next_index += 1;
                remaining = next_index - 4;
            }
        }
    }

    fn checkedPointer(self: *Model, comptime T: type, offset: usize) *T {
        if (offset > self.memory.len or @sizeOf(T) > self.memory.len - offset or
            offset % @alignOf(T) != 0)
            @panic("PPMd8 internal offset is out of bounds");
        const unaligned: *align(1) T = @ptrCast(self.memory[offset..].ptr);
        return @alignCast(unaligned);
    }

    pub fn context(self: *Model, offset: Offset) *Context {
        return self.checkedPointer(Context, offset.value);
    }

    pub fn state(self: *Model, offset: Offset) *State {
        return self.checkedPointer(State, offset.value);
    }

    pub fn stateAt(self: *Model, offset: Offset, index: usize) *State {
        return self.checkedPointer(State, @as(usize, offset.value) + index * @sizeOf(State));
    }

    pub fn singleState(self: *Model, context_offset: Offset) *State {
        return self.checkedPointer(State, @as(usize, context_offset.value) + @offsetOf(Context, "union2"));
    }

    pub fn multiState(self: *Model, context_offset: Offset) *State {
        return self.state(self.context(context_offset).union4.stats);
    }

    pub fn isRealContext(self: *const Model, offset: Offset) bool {
        return !offset.isNull() and offset.value >= self.units_start and
            offset.isValidFor(self.memory.len, Context);
    }

    fn node(self: *Model, offset: Offset) *Node {
        return self.checkedPointer(Node, offset.value);
    }

    fn insertNode(self: *Model, node_offset: Offset, index: usize) void {
        const item = self.node(node_offset);
        item.stamp = empty_node;
        item.next = self.free_list[index];
        item.units = self.index2units[index];
        self.free_list[index] = node_offset;
        self.stamps[index] +%= 1;
    }

    fn removeNode(self: *Model, index: usize) Offset {
        const result = self.free_list[index];
        std.debug.assert(!result.isNull());
        self.free_list[index] = self.node(result).next;
        self.stamps[index] -%= 1;
        return result;
    }

    fn splitBlock(self: *Model, block: Offset, old_index: usize, new_index: usize) void {
        const used_units = self.index2units[new_index];
        const remaining_units = self.index2units[old_index] - used_units;
        const remainder = Offset.init(@as(usize, block.value) + @as(usize, used_units) * unit_size);
        var index: usize = self.units2index[remaining_units - 1];
        if (self.index2units[index] != remaining_units) {
            index -= 1;
            const first_units = self.index2units[index];
            self.insertNode(
                Offset.init(@as(usize, remainder.value) + @as(usize, first_units) * unit_size),
                remaining_units - first_units - 1,
            );
        }
        self.insertNode(remainder, index);
    }

    fn glueFreeBlocks(self: *Model) void {
        self.glue_count = 1 << 13;
        self.stamps = @splat(0);
        if (self.lo_unit != self.hi_unit)
            self.checkedPointer(Node, self.lo_unit).stamp = 0;

        var head: Offset = .null_offset;
        var tail: Offset = .null_offset;
        for (0..num_indexes) |index| {
            var next = self.free_list[index];
            self.free_list[index] = .null_offset;
            while (!next.isNull()) {
                const current = next;
                const item = self.node(current);
                next = item.next;
                var units = item.units;
                if (units == 0) continue;
                while (self.node(Offset.init(@as(usize, current.value) + @as(usize, units) * unit_size)).stamp == empty_node) {
                    const adjacent = self.node(Offset.init(@as(usize, current.value) + @as(usize, units) * unit_size));
                    units += adjacent.units;
                    item.units = units;
                    adjacent.units = 0;
                }
                item.next = .null_offset;
                if (head.isNull()) head = current else self.node(tail).next = current;
                tail = current;
            }
        }

        var next = head;
        while (!next.isNull()) {
            var item_offset = next;
            var item = self.node(item_offset);
            var units: usize = item.units;
            next = item.next;
            if (units == 0) continue;
            while (units > 128) {
                self.insertNode(item_offset, num_indexes - 1);
                units -= 128;
                item_offset = Offset.init(@as(usize, item_offset.value) + 128 * unit_size);
                item = self.node(item_offset);
            }
            var index: usize = self.units2index[units - 1];
            if (self.index2units[index] != units) {
                index -= 1;
                const first_units = self.index2units[index];
                self.insertNode(
                    Offset.init(@as(usize, item_offset.value) + @as(usize, first_units) * unit_size),
                    units - first_units - 1,
                );
            }
            self.insertNode(item_offset, index);
        }
    }

    fn allocUnitsRare(self: *Model, index: usize) ?Offset {
        if (self.glue_count == 0) {
            self.glueFreeBlocks();
            if (!self.free_list[index].isNull()) return self.removeNode(index);
        }
        var larger_index = index + 1;
        while (larger_index < num_indexes and self.free_list[larger_index].isNull())
            larger_index += 1;
        if (larger_index == num_indexes) {
            const bytes = @as(usize, self.index2units[index]) * unit_size;
            self.glue_count -= 1;
            if (self.units_start - self.text <= bytes) return null;
            self.units_start -= bytes;
            return Offset.init(self.units_start);
        }
        const block = self.removeNode(larger_index);
        self.splitBlock(block, larger_index, index);
        return block;
    }

    fn allocUnits(self: *Model, index: usize) ?Offset {
        if (!self.free_list[index].isNull()) return self.removeNode(index);
        const bytes = @as(usize, self.index2units[index]) * unit_size;
        if (self.hi_unit - self.lo_unit >= bytes) {
            const result = Offset.init(self.lo_unit);
            self.lo_unit += bytes;
            return result;
        }
        return self.allocUnitsRare(index);
    }

    fn shrinkUnits(self: *Model, old: Offset, old_units: usize, new_units: usize) Offset {
        const old_index: usize = self.units2index[old_units - 1];
        const new_index: usize = self.units2index[new_units - 1];
        if (old_index == new_index) return old;
        if (!self.free_list[new_index].isNull()) {
            const replacement = self.removeNode(new_index);
            const byte_count = new_units * unit_size;
            @memcpy(self.memory[replacement.value..][0..byte_count], self.memory[old.value..][0..byte_count]);
            self.insertNode(old, old_index);
            return replacement;
        }
        self.splitBlock(old, old_index, new_index);
        return old;
    }

    fn freeUnits(self: *Model, offset: Offset, units: usize) void {
        self.insertNode(offset, self.units2index[units - 1]);
    }

    fn specialFreeUnit(self: *Model, offset: Offset) void {
        if (offset.value != self.units_start)
            self.insertNode(offset, 0)
        else
            self.units_start += unit_size;
    }

    fn expandTextArea(self: *Model) void {
        var counts: [num_indexes]u32 = @splat(0);
        if (self.lo_unit != self.hi_unit)
            self.checkedPointer(Node, self.lo_unit).stamp = 0;
        var scan = Offset.init(self.units_start);
        while (self.node(scan).stamp == empty_node) {
            const units = self.node(scan).units;
            self.node(scan).stamp = 0;
            counts[self.units2index[units - 1]] += 1;
            scan.value += @intCast(units * unit_size);
        }
        self.units_start = scan.value;

        for (0..num_indexes) |index| {
            var remove_count = counts[index];
            if (remove_count == 0) continue;
            var old = self.free_list[index];
            var new_head: Offset = .null_offset;
            var tail: Offset = .null_offset;
            while (!old.isNull()) {
                const current = old;
                const item = self.node(current);
                old = item.next;
                if (item.stamp == 0 and remove_count != 0) {
                    remove_count -= 1;
                    self.stamps[index] -%= 1;
                    continue;
                }
                item.next = .null_offset;
                if (new_head.isNull()) new_head = current else self.node(tail).next = current;
                tail = current;
            }
            std.debug.assert(remove_count == 0);
            self.free_list[index] = new_head;
        }
    }

    pub fn restart(self: *Model) void {
        self.free_list = @splat(.null_offset);
        self.stamps = @splat(0);
        self.text = self.align_offset;
        self.hi_unit = self.text + self.memory_size;
        const unit_area_size = (@as(usize, self.memory_size) / 8 / unit_size) * 7 * unit_size;
        self.units_start = self.hi_unit - unit_area_size;
        self.lo_unit = self.units_start;
        self.glue_count = 0;
        self.order_fall = self.max_order_value;
        self.init_rl = -@as(i32, @intCast(@min(self.max_order_value, 12))) - 1;
        self.run_length = self.init_rl;
        self.prev_success = 0;

        self.hi_unit -= unit_size;
        const root_offset = Offset.init(self.hi_unit);
        const stats_offset = Offset.init(self.lo_unit);
        self.lo_unit += 128 * unit_size;
        self.min_context = root_offset;
        self.max_context = root_offset;
        self.found_state = stats_offset;
        const root = self.context(root_offset);
        root.flags = 0;
        root.num_stats = 255;
        root.union2.summ_freq = 257;
        root.union4.stats = stats_offset;
        root.suffix = .null_offset;
        for (0..256) |symbol| {
            const root_state = self.stateAt(stats_offset, symbol);
            root_state.symbol = @intCast(symbol);
            root_state.freq = 1;
            root_state.setSuccessor(.null_offset);
        }

        var stats_count: usize = 0;
        for (0..25) |row| {
            while (self.ns2index[stats_count] == row) stats_count += 1;
            for (0..8) |escape_index| {
                const value = bin_scale - @as(u32, init_bin_escape[escape_index]) /
                    @as(u32, @intCast(stats_count + 1));
                var column = escape_index;
                while (column < 64) : (column += 8)
                    self.bin_summ[row][column] = @intCast(value);
            }
        }

        stats_count = 0;
        for (0..24) |row| {
            while (self.ns2index[stats_count + 3] == row + 3) stats_count += 1;
            const summ = (@as(u32, @intCast(2 * stats_count)) + 5) << (period_bits - 4);
            for (&self.see[row]) |*item| item.* = .{
                .summ = @intCast(summ),
                .shift = period_bits - 4,
                .count = 7,
            };
        }
        self.dummy_see = .{ .summ = 0, .shift = period_bits, .count = 64 };
    }

    fn hiBitsPrepare(symbol: u8) u32 {
        return @as(u32, symbol) + 0xc0;
    }

    fn hiBitsConvert3(value: u32) u32 {
        return value >> 5 & 8;
    }

    fn hiBitsConvert4(value: u32) u32 {
        return value >> 4 & 16;
    }

    fn hiBitsFlag3(symbol: u8) u32 {
        return hiBitsConvert3(hiBitsPrepare(symbol));
    }

    fn hiBitsFlag4(symbol: u8) u32 {
        return hiBitsConvert4(hiBitsPrepare(symbol));
    }

    fn refresh(self: *Model, context_offset: Offset, old_units: usize, scale: u1) void {
        const context_record = self.context(context_offset);
        const stats_count = @as(usize, context_record.num_stats);
        const old_stats = context_record.union4.stats;
        const stats_offset = self.shrinkUnits(old_stats, old_units, (stats_count + 2) >> 1);
        context_record.union4.stats = stats_offset;

        const effective_scale: u1 = @intCast(scale | @intFromBool(context_record.union2.summ_freq >= 1 << 15));
        var flags = hiBitsPrepare(self.state(stats_offset).symbol);
        var frequency = @as(u32, self.state(stats_offset).freq);
        var escape_frequency = @as(u32, context_record.union2.summ_freq) - frequency;
        frequency = (frequency + effective_scale) >> effective_scale;
        var sum_frequency = frequency;
        self.state(stats_offset).freq = @intCast(frequency);
        for (1..stats_count + 1) |index| {
            const selected = self.stateAt(stats_offset, index);
            frequency = selected.freq;
            escape_frequency -= frequency;
            frequency = (frequency + effective_scale) >> effective_scale;
            sum_frequency += frequency;
            selected.freq = @intCast(frequency);
            flags |= hiBitsPrepare(selected.symbol);
        }
        context_record.union2.summ_freq = @intCast(
            sum_frequency + ((escape_frequency + effective_scale) >> effective_scale),
        );
        context_record.flags = @intCast(
            (@as(u32, context_record.flags) &
                (@as(u32, flag_prev_high) + @as(u32, flag_rescaled) * effective_scale)) +
                hiBitsConvert3(flags),
        );
    }

    fn cutOff(self: *Model, context_offset: Offset, order: u32) Offset {
        const context_record = self.context(context_offset);
        var stats_count: i32 = context_record.num_stats;
        if (stats_count == 0) {
            const single = self.singleState(context_offset);
            var successor = single.successor();
            if (self.isRealContext(successor)) {
                successor = if (order < self.max_order_value)
                    self.cutOff(successor, order + 1)
                else
                    .null_offset;
                single.setSuccessor(successor);
                if (!successor.isNull() or order <= 9) return context_offset;
            }
            self.specialFreeUnit(context_offset);
            return .null_offset;
        }

        const units: usize = (@as(usize, @intCast(stats_count)) + 2) >> 1;
        const index: usize = self.units2index[units - 1];
        var stats_offset = context_record.union4.stats;
        if (@as(usize, stats_offset.value) - self.units_start <= 1 << 14 and
            stats_offset.value <= self.free_list[index].value)
        {
            const replacement = self.removeNode(index);
            context_record.union4.stats = replacement;
            @memcpy(
                self.memory[replacement.value..][0 .. units * unit_size],
                self.memory[stats_offset.value..][0 .. units * unit_size],
            );
            if (stats_offset.value != self.units_start)
                self.insertNode(stats_offset, index)
            else
                self.units_start += @as(usize, self.index2units[index]) * unit_size;
            stats_offset = replacement;
        }

        var state_index = stats_count;
        while (state_index >= 0) : (state_index -= 1) {
            const selected_offset = Offset.init(
                @as(usize, stats_offset.value) + @as(usize, @intCast(state_index)) * @sizeOf(State),
            );
            const selected = self.state(selected_offset);
            const successor = selected.successor();
            if (!self.isRealContext(successor)) {
                const last_index = stats_count;
                stats_count -= 1;
                const last_offset = Offset.init(
                    @as(usize, stats_offset.value) + @as(usize, @intCast(last_index)) * @sizeOf(State),
                );
                if (order != 0) {
                    if (selected_offset.value != last_offset.value)
                        selected.* = self.state(last_offset).*;
                } else {
                    const temporary = selected.*;
                    selected.* = self.state(last_offset).*;
                    self.state(last_offset).* = temporary;
                    self.state(last_offset).setSuccessor(.null_offset);
                }
            } else if (order < self.max_order_value) {
                selected.setSuccessor(self.cutOff(successor, order + 1));
            } else {
                selected.setSuccessor(.null_offset);
            }
        }

        if (stats_count != context_record.num_stats and order != 0) {
            if (stats_count < 0) {
                self.freeUnits(stats_offset, units);
                self.specialFreeUnit(context_offset);
                return .null_offset;
            }
            context_record.num_stats = @intCast(stats_count);
            if (stats_count == 0) {
                const first = self.state(stats_offset);
                context_record.flags = @intCast(
                    (@as(u32, context_record.flags & flag_prev_high)) + hiBitsFlag3(first.symbol),
                );
                const symbol = first.symbol;
                const frequency: u8 = @intCast((@as(u32, first.freq) + 11) >> 3);
                const successor = first.successor();
                context_record.union2.state = .{ .symbol = symbol, .freq = frequency };
                context_record.union4.state.setSuccessor(successor);
                self.freeUnits(stats_offset, units);
            } else {
                self.refresh(
                    context_offset,
                    units,
                    @intCast(@intFromBool(context_record.union2.summ_freq > 16 * @as(u32, @intCast(stats_count)))),
                );
            }
        }
        return context_offset;
    }

    fn usedMemory(self: *Model) u32 {
        var free_units: u32 = 0;
        for (0..num_indexes) |index|
            free_units += self.stamps[index] * self.index2units[index];
        return self.memory_size -
            @as(u32, @intCast(self.hi_unit - self.lo_unit)) -
            @as(u32, @intCast(self.units_start - self.text)) -
            free_units * @as(u32, unit_size);
    }

    fn restoreModel(self: *Model, error_context: Offset) void {
        self.text = self.align_offset;
        var context_offset = self.max_context;
        while (context_offset.value != error_context.value) {
            const context_record = self.context(context_offset);
            context_record.num_stats -= 1;
            if (context_record.num_stats == 0) {
                const stats_offset = context_record.union4.stats;
                const first = self.state(stats_offset);
                context_record.flags = @intCast(
                    (@as(u32, context_record.flags & flag_prev_high)) + hiBitsFlag3(first.symbol),
                );
                const symbol = first.symbol;
                const frequency: u8 = @intCast((@as(u32, first.freq) + 11) >> 3);
                const successor = first.successor();
                context_record.union2.state = .{ .symbol = symbol, .freq = frequency };
                context_record.union4.state.setSuccessor(successor);
                self.specialFreeUnit(stats_offset);
            } else {
                self.refresh(context_offset, (@as(usize, context_record.num_stats) + 3) >> 1, 0);
            }
            context_offset = context_record.suffix;
        }

        while (context_offset.value != self.min_context.value) {
            const context_record = self.context(context_offset);
            if (context_record.num_stats == 0) {
                context_record.union2.state.freq = @intCast(
                    (@as(u32, context_record.union2.state.freq) + 1) >> 1,
                );
            } else {
                context_record.union2.summ_freq += 4;
                if (context_record.union2.summ_freq > 128 + 4 * @as(u32, context_record.num_stats))
                    self.refresh(context_offset, (@as(usize, context_record.num_stats) + 2) >> 1, 1);
            }
            context_offset = context_record.suffix;
        }

        if (self.restore_method == .restart or self.usedMemory() < self.memory_size >> 1) {
            self.restart();
        } else {
            while (!self.context(self.max_context).suffix.isNull())
                self.max_context = self.context(self.max_context).suffix;
            while (true) {
                _ = self.cutOff(self.max_context, 0);
                self.expandTextArea();
                if (self.usedMemory() <= 3 * (self.memory_size >> 2)) break;
            }
            self.glue_count = 0;
            self.order_fall = self.max_order_value;
        }
        self.min_context = self.max_context;
    }

    fn createSuccessors(
        self: *Model,
        skip_found: bool,
        state_hint: *?Offset,
        initial_context: Offset,
    ) ?Offset {
        var context_offset = initial_context;
        const up_branch = self.state(self.found_state).successor();
        if (up_branch.isNull() or up_branch.value >= self.memory.len) return null;
        var pending_count: usize = 0;
        var pending: [max_order + 1]?Offset = @splat(null);
        if (!skip_found) {
            pending[0] = self.found_state;
            pending_count = 1;
        }

        while (!self.context(context_offset).suffix.isNull()) {
            context_offset = self.context(context_offset).suffix;
            const context_record = self.context(context_offset);
            const selected_offset = if (state_hint.*) |hint| selected: {
                state_hint.* = null;
                break :selected hint;
            } else if (context_record.num_stats != 0) selected: {
                var candidate = context_record.union4.stats;
                const symbol = self.state(self.found_state).symbol;
                while (self.state(candidate).symbol != symbol)
                    candidate.value += @sizeOf(State);
                if (self.state(candidate).freq < max_frequency - 9) {
                    self.state(candidate).freq += 1;
                    context_record.union2.summ_freq += 1;
                }
                break :selected candidate;
            } else selected: {
                const candidate = Offset.init(
                    @as(usize, context_offset.value) + @offsetOf(Context, "union2"),
                );
                const suffix_is_binary = self.context(context_record.suffix).num_stats == 0;
                if (suffix_is_binary and self.state(candidate).freq < 24)
                    self.state(candidate).freq += 1;
                break :selected candidate;
            };

            const successor = self.state(selected_offset).successor();
            if (successor.value != up_branch.value) {
                if (!self.isRealContext(successor)) return null;
                context_offset = successor;
                if (pending_count == 0) return context_offset;
                break;
            }
            if (pending_count == pending.len) return null;
            pending[pending_count] = selected_offset;
            pending_count += 1;
        }

        const new_symbol = self.memory[up_branch.value];
        const next_raw_successor = Offset{ .value = up_branch.value + 1 };
        const flags: u8 = @intCast(
            hiBitsFlag4(self.state(self.found_state).symbol) + hiBitsFlag3(new_symbol),
        );
        const new_frequency: u8 = if (self.context(context_offset).num_stats == 0)
            self.context(context_offset).union2.state.freq
        else frequency: {
            const context_record = self.context(context_offset);
            var candidate = context_record.union4.stats;
            while (self.state(candidate).symbol != new_symbol)
                candidate.value += @sizeOf(State);
            const candidate_frequency = @as(u32, self.state(candidate).freq) - 1;
            const other_frequency = @as(u32, context_record.union2.summ_freq) -
                context_record.num_stats - candidate_frequency;
            const increment = if (2 * candidate_frequency <= other_frequency)
                @intFromBool(5 * candidate_frequency > other_frequency)
            else
                (candidate_frequency + 2 * other_frequency - 3) / other_frequency;
            break :frequency @intCast(1 + increment);
        };

        while (pending_count != 0) {
            const new_context_offset = if (self.hi_unit != self.lo_unit) allocate: {
                self.hi_unit -= unit_size;
                break :allocate Offset.init(self.hi_unit);
            } else if (!self.free_list[0].isNull())
                self.removeNode(0)
            else
                self.allocUnitsRare(0) orelse return null;
            const new_context = self.context(new_context_offset);
            new_context.flags = flags;
            new_context.num_stats = 0;
            new_context.union2.state = .{ .symbol = new_symbol, .freq = new_frequency };
            new_context.union4.state.setSuccessor(next_raw_successor);
            new_context.suffix = context_offset;

            pending_count -= 1;
            self.state(pending[pending_count].?).setSuccessor(new_context_offset);
            context_offset = new_context_offset;
        }
        return context_offset;
    }

    fn reduceOrder(
        self: *Model,
        initial_hint: ?Offset,
        initial_context: Offset,
    ) ?Offset {
        var state_hint = initial_hint;
        var context_offset = initial_context;
        const original_context = context_offset;
        const up_branch = Offset.init(self.text);
        self.state(self.found_state).setSuccessor(up_branch);
        self.order_fall += 1;
        var selected_offset: Offset = undefined;

        while (true) {
            if (state_hint) |hint| {
                context_offset = self.context(context_offset).suffix;
                selected_offset = hint;
                state_hint = null;
            } else {
                const suffix = self.context(context_offset).suffix;
                if (suffix.isNull()) return context_offset;
                context_offset = suffix;
                const context_record = self.context(context_offset);
                if (context_record.num_stats != 0) {
                    selected_offset = context_record.union4.stats;
                    const symbol = self.state(self.found_state).symbol;
                    while (self.state(selected_offset).symbol != symbol)
                        selected_offset.value += @sizeOf(State);
                    if (self.state(selected_offset).freq < max_frequency - 9) {
                        self.state(selected_offset).freq += 2;
                        context_record.union2.summ_freq += 2;
                    }
                } else {
                    selected_offset = Offset.init(
                        @as(usize, context_offset.value) + @offsetOf(Context, "union2"),
                    );
                    if (self.state(selected_offset).freq < 32)
                        self.state(selected_offset).freq += 1;
                }
            }
            if (!self.state(selected_offset).successor().isNull()) break;
            self.state(selected_offset).setSuccessor(up_branch);
            self.order_fall += 1;
        }

        if (self.state(selected_offset).successor().value <= up_branch.value) {
            const saved_found = self.found_state;
            self.found_state = selected_offset;
            var no_hint: ?Offset = null;
            if (self.createSuccessors(false, &no_hint, context_offset)) |successor|
                self.state(selected_offset).setSuccessor(successor)
            else
                self.state(selected_offset).setSuccessor(.null_offset);
            self.found_state = saved_found;
        }

        const successor = self.state(selected_offset).successor();
        if (self.order_fall == 1 and original_context.value == self.max_context.value) {
            self.state(self.found_state).setSuccessor(successor);
            self.text -= 1;
        }
        if (successor.isNull() or !self.isRealContext(successor)) return null;
        return successor;
    }

    fn updateModel(self: *Model) void {
        var min_successor = self.state(self.found_state).successor();
        const found_frequency = @as(u32, self.state(self.found_state).freq);
        const found_symbol = self.state(self.found_state).symbol;
        var state_hint: ?Offset = null;
        if (self.state(self.found_state).freq < max_frequency / 4 and
            !self.context(self.min_context).suffix.isNull())
        {
            const suffix_offset = self.context(self.min_context).suffix;
            const suffix = self.context(suffix_offset);
            if (suffix.num_stats == 0) {
                const selected = Offset.init(
                    @as(usize, suffix_offset.value) + @offsetOf(Context, "union2"),
                );
                if (self.state(selected).freq < 32) self.state(selected).freq += 1;
                state_hint = selected;
            } else {
                var selected = suffix.union4.stats;
                while (self.state(selected).symbol != found_symbol)
                    selected.value += @sizeOf(State);
                const first = suffix.union4.stats;
                if (selected.value != first.value) {
                    const previous = Offset{ .value = selected.value - @sizeOf(State) };
                    if (self.state(selected).freq >= self.state(previous).freq) {
                        const temporary = self.state(selected).*;
                        self.state(selected).* = self.state(previous).*;
                        self.state(previous).* = temporary;
                        selected = previous;
                    }
                }
                if (self.state(selected).freq < max_frequency - 9) {
                    self.state(selected).freq += 2;
                    suffix.union2.summ_freq += 2;
                }
                state_hint = selected;
            }
        }

        var context_offset = self.max_context;
        if (self.order_fall == 0 and !min_successor.isNull()) {
            const successor = self.createSuccessors(true, &state_hint, self.min_context) orelse {
                self.state(self.found_state).setSuccessor(.null_offset);
                self.restoreModel(context_offset);
                return;
            };
            self.state(self.found_state).setSuccessor(successor);
            self.max_context = successor;
            self.min_context = successor;
            return;
        }

        self.memory[self.text] = found_symbol;
        self.text += 1;
        if (self.text >= self.units_start) {
            self.restoreModel(context_offset);
            return;
        }
        var max_successor = Offset.init(self.text);
        if (min_successor.isNull()) {
            min_successor = self.reduceOrder(state_hint, self.min_context) orelse {
                self.restoreModel(context_offset);
                return;
            };
        } else if (!self.isRealContext(min_successor)) {
            min_successor = self.createSuccessors(false, &state_hint, self.min_context) orelse {
                self.restoreModel(context_offset);
                return;
            };
        }

        self.order_fall -= 1;
        if (self.order_fall == 0) {
            max_successor = min_successor;
            self.text -= @intFromBool(self.max_context.value != self.min_context.value);
        }

        const flag: u8 = @intCast(hiBitsFlag3(found_symbol));
        const min_context_record = self.context(self.min_context);
        const min_stats_count = @as(u32, min_context_record.num_stats);
        const escape_frequency = @as(u32, min_context_record.union2.summ_freq) -
            min_stats_count - found_frequency;
        while (context_offset.value != self.min_context.value) {
            const context_record = self.context(context_offset);
            const stats_count = @as(u32, context_record.num_stats);
            var sum: u32 = undefined;
            if (stats_count != 0) {
                if (stats_count & 1 != 0) {
                    const old_units = (stats_count + 1) >> 1;
                    const old_index: usize = self.units2index[old_units - 1];
                    if (old_index != self.units2index[old_units]) {
                        const new_stats = self.allocUnits(old_index + 1) orelse {
                            self.restoreModel(context_offset);
                            return;
                        };
                        const old_stats = context_record.union4.stats;
                        const byte_count = @as(usize, old_units) * unit_size;
                        @memcpy(
                            self.memory[new_stats.value..][0..byte_count],
                            self.memory[old_stats.value..][0..byte_count],
                        );
                        self.insertNode(old_stats, old_index);
                        context_record.union4.stats = new_stats;
                    }
                }
                sum = context_record.union2.summ_freq +
                    @intFromBool(3 * stats_count + 1 < min_stats_count);
            } else {
                const new_stats = self.allocUnits(0) orelse {
                    self.restoreModel(context_offset);
                    return;
                };
                const first = self.state(new_stats);
                var frequency = @as(u32, context_record.union2.state.freq);
                first.symbol = context_record.union2.state.symbol;
                first.setSuccessor(context_record.union4.state.successor());
                context_record.union4.stats = new_stats;
                frequency = if (frequency < max_frequency / 4 - 1)
                    frequency << 1
                else
                    max_frequency - 4;
                first.freq = @intCast(frequency);
                sum = frequency + self.init_esc + @intFromBool(min_stats_count > 2);
            }

            const new_state_offset = Offset.init(
                @as(usize, context_record.union4.stats.value) +
                    @as(usize, stats_count + 1) * @sizeOf(State),
            );
            const new_state = self.state(new_state_offset);
            var frequency = 2 * (sum + 6) * found_frequency;
            const total = escape_frequency + sum;
            new_state.symbol = found_symbol;
            context_record.num_stats = @intCast(stats_count + 1);
            new_state.setSuccessor(max_successor);
            context_record.flags |= flag;
            if (frequency < 6 * total) {
                frequency = @as(u32, 1) + @intFromBool(frequency > total) +
                    @as(u32, @intFromBool(frequency >= 4 * total));
                sum += 4;
            } else {
                frequency = @as(u32, 4) + @intFromBool(frequency > 9 * total) +
                    @as(u32, @intFromBool(frequency > 12 * total)) +
                    @as(u32, @intFromBool(frequency > 15 * total));
                sum += frequency;
            }
            context_record.union2.summ_freq = @intCast(sum);
            new_state.freq = @intCast(frequency);
            context_offset = context_record.suffix;
        }
        self.min_context = min_successor;
        self.max_context = min_successor;
    }

    fn rescale(self: *Model) void {
        const stats_offset = self.context(self.min_context).union4.stats;
        var current = self.found_state;
        if (current.value != stats_offset.value) {
            const selected = self.state(current).*;
            while (current.value != stats_offset.value) {
                const previous = Offset{ .value = current.value - @sizeOf(State) };
                self.state(current).* = self.state(previous).*;
                current = previous;
            }
            self.state(current).* = selected;
        }

        var sum_frequency = @as(u32, self.state(current).freq);
        var escape_frequency = @as(u32, self.context(self.min_context).union2.summ_freq) - sum_frequency;
        const adder: u32 = @intFromBool(self.order_fall != 0);
        sum_frequency = (sum_frequency + 4 + adder) >> 1;
        self.state(current).freq = @intCast(sum_frequency);
        var remaining = @as(u32, self.context(self.min_context).num_stats);
        while (remaining != 0) : (remaining -= 1) {
            current.value += @sizeOf(State);
            var frequency = @as(u32, self.state(current).freq);
            escape_frequency -= frequency;
            frequency = (frequency + adder) >> 1;
            sum_frequency += frequency;
            self.state(current).freq = @intCast(frequency);
            const previous = Offset{ .value = current.value - @sizeOf(State) };
            if (frequency > self.state(previous).freq) {
                const selected = self.state(current).*;
                var insertion = current;
                while (true) {
                    const insertion_previous = Offset{ .value = insertion.value - @sizeOf(State) };
                    self.state(insertion).* = self.state(insertion_previous).*;
                    insertion = insertion_previous;
                    if (insertion.value == stats_offset.value) break;
                    const before = Offset{ .value = insertion.value - @sizeOf(State) };
                    if (frequency <= self.state(before).freq) break;
                }
                self.state(insertion).* = selected;
            }
        }

        if (self.state(current).freq == 0) {
            var removed: u32 = 0;
            while (self.state(current).freq == 0) {
                removed += 1;
                current.value -= @sizeOf(State);
            }
            escape_frequency += removed;
            const context_record = self.context(self.min_context);
            const old_stats_count = @as(u32, context_record.num_stats);
            const new_stats_count = old_stats_count - removed;
            context_record.num_stats = @intCast(new_stats_count);
            const old_units = (old_stats_count + 2) >> 1;
            if (new_stats_count == 0) {
                var frequency = std.math.divCeil(u32, 2 * self.state(stats_offset).freq, escape_frequency) catch unreachable;
                frequency = @min(frequency, max_frequency / 3);
                const first = self.state(stats_offset);
                context_record.flags = @intCast(
                    (@as(u32, context_record.flags & flag_prev_high)) + hiBitsFlag3(first.symbol),
                );
                const single_offset = Offset.init(
                    @as(usize, self.min_context.value) + @offsetOf(Context, "union2"),
                );
                self.state(single_offset).* = first.*;
                self.state(single_offset).freq = @intCast(frequency);
                self.found_state = single_offset;
                self.insertNode(stats_offset, self.units2index[old_units - 1]);
                return;
            }
            const new_units = (new_stats_count + 2) >> 1;
            if (old_units != new_units)
                context_record.union4.stats = self.shrinkUnits(stats_offset, old_units, new_units);
        }
        const context_record = self.context(self.min_context);
        context_record.union2.summ_freq = @intCast(
            sum_frequency + escape_frequency - (escape_frequency >> 1),
        );
        context_record.flags |= flag_rescaled;
        self.found_state = context_record.union4.stats;
    }

    pub fn makeEscFreq(self: *Model, masked_count: u32, escape_frequency: *u32) SeeSource {
        const stats_count = @as(u32, self.context(self.min_context).num_stats);
        if (stats_count == 0xff) {
            escape_frequency.* = 1;
            return .dummy;
        }
        const row: usize = self.ns2index[stats_count + 2] - 3;
        const context_record = self.context(self.min_context);
        const suffix_stats = @as(u32, self.context(context_record.suffix).num_stats);
        const column = @as(usize, @intFromBool(context_record.union2.summ_freq > 11 * (stats_count + 1))) +
            2 * @as(usize, @intFromBool(2 * stats_count < suffix_stats + masked_count)) +
            context_record.flags;
        const selected = &self.see[row][column];
        const summ = @as(u32, selected.summ);
        const value = summ >> @intCast(selected.shift);
        selected.summ = @truncate(summ - value);
        escape_frequency.* = value + @intFromBool(value == 0);
        return .{ .table = .{ .row = row, .column = column } };
    }

    pub fn getSee(self: *Model, source: SeeSource) *See {
        return switch (source) {
            .dummy => &self.dummy_see,
            .table => |location| &self.see[location.row][location.column],
        };
    }

    fn nextContext(self: *Model) void {
        const successor = self.state(self.found_state).successor();
        if (self.order_fall == 0 and self.isRealContext(successor)) {
            self.min_context = successor;
            self.max_context = successor;
        } else {
            self.updateModel();
        }
    }

    pub fn update1(self: *Model) void {
        var selected_offset = self.found_state;
        const frequency = @as(u32, self.state(selected_offset).freq) + 4;
        self.context(self.min_context).union2.summ_freq += 4;
        self.state(selected_offset).freq = @intCast(frequency);
        const previous = Offset{ .value = selected_offset.value - @sizeOf(State) };
        if (frequency > self.state(previous).freq) {
            const temporary = self.state(selected_offset).*;
            self.state(selected_offset).* = self.state(previous).*;
            self.state(previous).* = temporary;
            selected_offset = previous;
            self.found_state = selected_offset;
            if (frequency > max_frequency) self.rescale();
        }
        self.nextContext();
    }

    pub fn update1_0(self: *Model) void {
        const selected = self.state(self.found_state);
        const context_record = self.context(self.min_context);
        var frequency = @as(u32, selected.freq);
        const sum_frequency = @as(u32, context_record.union2.summ_freq);
        self.prev_success = @intFromBool(2 * frequency >= sum_frequency);
        self.run_length += @intCast(self.prev_success);
        context_record.union2.summ_freq = @intCast(sum_frequency + 4);
        frequency += 4;
        selected.freq = @intCast(frequency);
        if (frequency > max_frequency) self.rescale();
        self.nextContext();
    }

    pub fn update2(self: *Model) void {
        const selected = self.state(self.found_state);
        const frequency = @as(u32, selected.freq) + 4;
        self.run_length = self.init_rl;
        self.context(self.min_context).union2.summ_freq += 4;
        selected.freq = @intCast(frequency);
        if (frequency > max_frequency) self.rescale();
        self.updateModel();
    }

    pub fn updateBin(self: *Model, selected_offset: Offset) u8 {
        const selected = self.state(selected_offset);
        const symbol = selected.symbol;
        const frequency = @as(u32, selected.freq);
        self.found_state = selected_offset;
        self.prev_success = 1;
        self.run_length += 1;
        selected.freq = @intCast(frequency + @intFromBool(frequency < 196));
        self.nextContext();
        return symbol;
    }

    pub fn getBinSumm(self: *Model) *u16 {
        const selected = self.singleState(self.min_context);
        const frequency_row: usize = self.ns2index[selected.freq - 1];
        const context_record = self.context(self.min_context);
        const suffix_stats = self.context(context_record.suffix).num_stats;
        const column = self.prev_success +
            ((@as(u32, @bitCast(self.run_length)) >> 26) & 0x20) +
            self.ns2bs_index[suffix_stats] + context_record.flags;
        return &self.bin_summ[frequency_row][column];
    }
};

comptime {
    if (@sizeOf(See) != 4) @compileError("PPMd8 See must be four bytes");
    if (@sizeOf(State) != 6) @compileError("PPMd8 State must be six bytes");
    if (@sizeOf(Context) != unit_size) @compileError("PPMd8 Context must be one unit");
    if (@sizeOf(Node) != unit_size) @compileError("PPMd8 Node must be one unit");
}

test "PPMd8 layouts and minimum model initialize" {
    var model = try Model.init(std.testing.allocator, min_order, min_memory_size, .restart);
    defer model.deinit();
    try std.testing.expectEqual(@as(u8, 255), model.context(model.min_context).num_stats);
    try std.testing.expectEqual(@as(u16, 257), model.context(model.min_context).union2.summ_freq);
    try std.testing.expect(model.text < model.units_start);
    try std.testing.expect(model.lo_unit <= model.hi_unit);
}

test "PPMd8 rejects invalid model limits" {
    try std.testing.expectError(
        error.InvalidPpmdOrder,
        Model.init(std.testing.allocator, min_order - 1, min_memory_size, .restart),
    );
    try std.testing.expectError(
        error.InvalidPpmdOrder,
        Model.init(std.testing.allocator, max_order + 1, min_memory_size, .restart),
    );
    try std.testing.expectError(
        error.InvalidPpmdMemorySize,
        Model.init(std.testing.allocator, min_order, min_memory_size - 1, .restart),
    );
}
