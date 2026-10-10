const std = @import("std");

pub const min_order: u8 = 2;
pub const max_order: u8 = 64;
pub const min_memory_size: u32 = 2 * 1024;
pub const max_memory_size: u32 = std.math.maxInt(u32) - 36;

pub const Error = std.mem.Allocator.Error || error{
    InvalidPpmdOrder,
    InvalidPpmdMemorySize,
};

pub const int_bits: u5 = 7;
pub const period_bits: u5 = 7;
pub const bin_scale: u32 = 1 << (int_bits + period_bits);
pub const max_frequency: u8 = 124;
pub const unit_size: usize = 12;

const n1: usize = 4;
const n2: usize = 4;
const n3: usize = 4;
const n4: usize = 26;
pub const num_indexes: usize = n1 + n2 + n3 + n4;
const empty_node: u16 = 0;

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
    num_stats: u16,
    union2: Union2,
    union4: Union4,
    suffix: Offset,
};

pub const Node = extern struct {
    stamp: u16,
    units: u16,
    next: Offset,
    previous: Offset,
};

pub const Model = struct {
    allocator: std.mem.Allocator,
    memory: []align(8) u8,
    memory_size: u32,
    align_offset: u2,
    max_order_value: u8,

    min_context: Offset = .null_offset,
    max_context: Offset = .null_offset,
    found_state: Offset = .null_offset,
    order_fall: u32 = 0,
    init_esc: u32 = 0,
    prev_success: u32 = 0,
    hi_bits_flag: u32 = 0,
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
    ns2bs_index: [256]u8 = @splat(0),
    ns2index: [256]u8 = @splat(0),
    dummy_see: See = .{},
    see: [25][16]See = @splat(@splat(.{})),
    bin_summ: [128][64]u16 = @splat(@splat(0)),

    pub fn init(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
    ) Error!Model {
        if (order < min_order or order > max_order) return error.InvalidPpmdOrder;
        if (memory_size < min_memory_size or memory_size > max_memory_size)
            return error.InvalidPpmdMemorySize;

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

        self.ns2index[0] = 0;
        self.ns2index[1] = 1;
        self.ns2index[2] = 2;
        var next_index: usize = 3;
        var remaining: usize = 1;
        for (3..256) |stats_count| {
            self.ns2index[stats_count] = @intCast(next_index);
            remaining -= 1;
            if (remaining == 0) {
                next_index += 1;
                remaining = next_index - 2;
            }
        }
    }

    pub fn restart(self: *Model) void {
        self.free_list = @splat(.null_offset);
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
        root.num_stats = 256;
        root.union2.summ_freq = 257;
        root.union4.stats = stats_offset;
        root.suffix = .null_offset;
        for (0..256) |symbol| {
            const root_state = self.stateAt(stats_offset, symbol);
            root_state.symbol = @intCast(symbol);
            root_state.freq = 1;
            root_state.setSuccessor(.null_offset);
        }

        for (0..128) |frequency_index| {
            for (0..8) |escape_index| {
                const value = bin_scale - @as(u32, init_bin_escape[escape_index]) /
                    @as(u32, @intCast(frequency_index + 2));
                var context_index = escape_index;
                while (context_index < 64) : (context_index += 8)
                    self.bin_summ[frequency_index][context_index] = @intCast(value);
            }
        }

        for (0..25) |index| {
            const summ = (@as(u32, @intCast(5 * index)) + 10) << (period_bits - 4);
            for (&self.see[index]) |*item| item.* = .{
                .summ = @intCast(summ),
                .shift = period_bits - 4,
                .count = 4,
            };
        }
        self.dummy_see = .{ .summ = 0, .shift = period_bits, .count = 64 };
    }

    fn checkedPointer(self: *Model, comptime T: type, offset: usize) *T {
        if (offset > self.memory.len or @sizeOf(T) > self.memory.len - offset or
            offset % @alignOf(T) != 0)
            @panic("PPMd7 internal offset is out of bounds");
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

    fn nextSlot(self: *Model, offset: Offset) *Offset {
        return self.checkedPointer(Offset, offset.value);
    }

    fn node(self: *Model, offset: Offset) *Node {
        return self.checkedPointer(Node, offset.value);
    }

    fn insertNode(self: *Model, node_offset: Offset, index: usize) void {
        self.nextSlot(node_offset).* = self.free_list[index];
        self.free_list[index] = node_offset;
    }

    fn removeNode(self: *Model, index: usize) Offset {
        const result = self.free_list[index];
        std.debug.assert(!result.isNull());
        self.free_list[index] = self.nextSlot(result).*;
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
        var list: Offset = .null_offset;
        self.glue_count = 255;
        if (self.lo_unit != self.hi_unit)
            self.checkedPointer(Node, self.lo_unit).stamp = 1;

        for (0..num_indexes) |index| {
            const units: u16 = self.index2units[index];
            var next = self.free_list[index];
            self.free_list[index] = .null_offset;
            while (!next.isNull()) {
                const item = self.node(next);
                const current = next;
                next = self.nextSlot(next).*;
                item.stamp = empty_node;
                item.units = units;
                item.next = list;
                list = current;
            }
        }

        var head = list;
        var current_link = &head;
        while (!current_link.*.isNull()) {
            const current_offset = current_link.*;
            const item = self.node(current_offset);
            var units: u32 = item.units;
            if (units == 0) {
                current_link.* = item.next;
                continue;
            }
            while (true) {
                const next_offset = Offset.init(@as(usize, current_offset.value) + @as(usize, units) * unit_size);
                const next = self.node(next_offset);
                const combined = units + next.units;
                if (next.stamp != empty_node or combined >= 0x10000) break;
                units = combined;
                item.units = @intCast(units);
                next.units = 0;
            }
            current_link = &item.next;
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

    pub fn allocUnits(self: *Model, index: usize) ?Offset {
        std.debug.assert(index < num_indexes);
        if (!self.free_list[index].isNull()) return self.removeNode(index);
        const bytes = @as(usize, self.index2units[index]) * unit_size;
        if (self.hi_unit - self.lo_unit >= bytes) {
            const result = Offset.init(self.lo_unit);
            self.lo_unit += bytes;
            return result;
        }
        return self.allocUnitsRare(index);
    }

    fn createSuccessors(self: *Model) ?Offset {
        var context_offset = self.min_context;
        const up_branch = self.state(self.found_state).successor();
        if (up_branch.isNull() or up_branch.value >= self.memory.len) return null;

        var pending_count: usize = 0;
        var pending: [max_order]?Offset = @splat(null);
        if (self.order_fall != 0) {
            pending[0] = self.found_state;
            pending_count = 1;
        }

        while (!self.context(context_offset).suffix.isNull()) {
            context_offset = self.context(context_offset).suffix;
            const context_record = self.context(context_offset);
            const state_offset = if (context_record.num_stats != 1) search: {
                const symbol = self.state(self.found_state).symbol;
                var candidate = context_record.union4.stats;
                while (self.state(candidate).symbol != symbol)
                    candidate.value += @sizeOf(State);
                break :search candidate;
            } else Offset.init(@as(usize, context_offset.value) + @offsetOf(Context, "union2"));

            const successor = self.state(state_offset).successor();
            if (successor.value != up_branch.value) {
                if (!self.isRealContext(successor)) return null;
                context_offset = successor;
                if (pending_count == 0) return context_offset;
                break;
            }
            if (pending_count == pending.len) return null;
            pending[pending_count] = state_offset;
            pending_count += 1;
        }

        const new_symbol = self.memory[up_branch.value];
        const next_raw_successor = Offset{ .value = up_branch.value + 1 };
        const new_frequency: u8 = if (self.context(context_offset).num_stats == 1)
            self.singleState(context_offset).freq
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
                (2 * candidate_frequency + other_frequency - 1) / (2 * other_frequency) + 1;
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
            new_context.num_stats = 1;
            const new_state = self.singleState(new_context_offset);
            new_state.symbol = new_symbol;
            new_state.freq = new_frequency;
            new_state.setSuccessor(next_raw_successor);
            new_context.suffix = context_offset;

            pending_count -= 1;
            self.state(pending[pending_count].?).setSuccessor(new_context_offset);
            context_offset = new_context_offset;
        }
        return context_offset;
    }

    fn updateModel(self: *Model) void {
        const original_min_context = self.min_context;
        const found = self.state(self.found_state);
        if (found.freq < max_frequency / 4 and
            !self.context(original_min_context).suffix.isNull())
        {
            const suffix_offset = self.context(original_min_context).suffix;
            const suffix = self.context(suffix_offset);
            if (suffix.num_stats == 1) {
                const suffix_state = self.singleState(suffix_offset);
                if (suffix_state.freq < 32) suffix_state.freq += 1;
            } else {
                var state_offset = suffix.union4.stats;
                if (self.state(state_offset).symbol != found.symbol) {
                    while (self.state(state_offset).symbol != found.symbol)
                        state_offset.value += @sizeOf(State);
                    const previous = Offset{ .value = state_offset.value - @sizeOf(State) };
                    if (self.state(state_offset).freq >= self.state(previous).freq) {
                        self.swapStates(state_offset);
                        state_offset = previous;
                    }
                }
                if (self.state(state_offset).freq < max_frequency - 9) {
                    self.state(state_offset).freq += 2;
                    suffix.union2.summ_freq += 2;
                }
            }
        }

        if (self.order_fall == 0) {
            const next = self.createSuccessors() orelse {
                self.restart();
                return;
            };
            self.min_context = next;
            self.max_context = next;
            self.state(self.found_state).setSuccessor(next);
            return;
        }

        const text_position = self.text;
        self.memory[text_position] = self.state(self.found_state).symbol;
        self.text += 1;
        if (self.text >= self.units_start) {
            self.restart();
            return;
        }
        var max_successor = Offset.init(self.text);
        var min_successor = self.state(self.found_state).successor();
        if (min_successor.isNull()) {
            self.state(self.found_state).setSuccessor(max_successor);
            min_successor = self.min_context;
        } else {
            if (min_successor.value <= max_successor.value) {
                min_successor = self.createSuccessors() orelse {
                    self.restart();
                    return;
                };
            }
            self.order_fall -= 1;
            if (self.order_fall == 0) {
                max_successor = min_successor;
                self.text -= @intFromBool(self.max_context.value != self.min_context.value);
            }
        }

        const min_context_before_advance = self.min_context;
        var context_offset = self.max_context;
        self.min_context = min_successor;
        self.max_context = min_successor;
        if (context_offset.value == min_context_before_advance.value) return;

        const min_context_record = self.context(min_context_before_advance);
        const min_stats_count = @as(u32, min_context_record.num_stats);
        const escape_frequency = @as(u32, min_context_record.union2.summ_freq) -
            min_stats_count - (@as(u32, self.state(self.found_state).freq) - 1);

        while (context_offset.value != min_context_before_advance.value) {
            const context_record = self.context(context_offset);
            var sum: u32 = undefined;
            const stats_count = @as(u32, context_record.num_stats);
            if (stats_count != 1) {
                if (stats_count & 1 == 0) {
                    const old_units = stats_count >> 1;
                    const old_index: usize = self.units2index[old_units - 1];
                    if (old_index != self.units2index[old_units]) {
                        const new_stats = self.allocUnits(old_index + 1) orelse {
                            self.restart();
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
                sum = context_record.union2.summ_freq;
                sum += @intFromBool(2 * stats_count < min_stats_count) +
                    2 * (@as(u32, @intFromBool(4 * stats_count <= min_stats_count)) &
                        @as(u32, @intFromBool(sum <= 8 * stats_count)));
            } else {
                const new_stats = self.allocUnits(0) orelse {
                    self.restart();
                    return;
                };
                const first_state = self.state(new_stats);
                var frequency = @as(u32, context_record.union2.state.freq);
                first_state.symbol = context_record.union2.state.symbol;
                first_state.setSuccessor(context_record.union4.state.successor());
                context_record.union4.stats = new_stats;
                frequency = if (frequency < max_frequency / 4 - 1)
                    frequency << 1
                else
                    max_frequency - 4;
                first_state.freq = @intCast(frequency);
                sum = frequency + self.init_esc + @intFromBool(min_stats_count > 3);
            }

            const new_state_offset = Offset.init(
                @as(usize, context_record.union4.stats.value) +
                    @as(usize, stats_count) * @sizeOf(State),
            );
            const new_state = self.state(new_state_offset);
            var frequency = 2 * (sum + 6) * self.state(self.found_state).freq;
            const total = escape_frequency + sum;
            new_state.symbol = self.state(self.found_state).symbol;
            context_record.num_stats = @intCast(stats_count + 1);
            new_state.setSuccessor(max_successor);
            if (frequency < 6 * total) {
                frequency = @as(u32, 1) + @intFromBool(frequency > total) +
                    @as(u32, @intFromBool(frequency >= 4 * total));
                sum += 3;
            } else {
                frequency = @as(u32, 4) + @intFromBool(frequency >= 9 * total) +
                    @as(u32, @intFromBool(frequency >= 12 * total)) +
                    @as(u32, @intFromBool(frequency >= 15 * total));
                sum += frequency;
            }
            context_record.union2.summ_freq = @intCast(sum);
            new_state.freq = @intCast(frequency);
            context_offset = context_record.suffix;
        }
    }

    fn swapStates(self: *Model, right_offset: Offset) void {
        const left_offset = Offset{ .value = right_offset.value - @sizeOf(State) };
        const temporary = self.state(right_offset).*;
        self.state(right_offset).* = self.state(left_offset).*;
        self.state(left_offset).* = temporary;
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
        var remaining = @as(u32, self.context(self.min_context).num_stats) - 1;
        self.state(current).freq = @intCast(sum_frequency);
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
            const new_stats_count = old_stats_count -% removed;
            context_record.num_stats = @intCast(new_stats_count);
            const old_units = (old_stats_count + 1) >> 1;
            if (new_stats_count == 1) {
                var frequency = @as(u32, self.state(stats_offset).freq);
                while (true) {
                    escape_frequency >>= 1;
                    frequency = (frequency + 1) >> 1;
                    if (escape_frequency <= 1) break;
                }
                const single_offset = Offset.init(
                    @as(usize, self.min_context.value) + @offsetOf(Context, "union2"),
                );
                self.state(single_offset).* = self.state(stats_offset).*;
                self.state(single_offset).freq = @intCast(frequency);
                self.found_state = single_offset;
                self.insertNode(stats_offset, self.units2index[old_units - 1]);
                return;
            }

            const new_units = (new_stats_count + 1) >> 1;
            if (old_units != new_units) {
                const old_index: usize = self.units2index[old_units - 1];
                const new_index: usize = self.units2index[new_units - 1];
                if (old_index != new_index) {
                    if (!self.free_list[new_index].isNull()) {
                        const new_stats = self.removeNode(new_index);
                        self.context(self.min_context).union4.stats = new_stats;
                        const byte_count = @as(usize, new_units) * unit_size;
                        @memcpy(
                            self.memory[new_stats.value..][0..byte_count],
                            self.memory[stats_offset.value..][0..byte_count],
                        );
                        self.insertNode(stats_offset, old_index);
                    } else {
                        self.splitBlock(stats_offset, old_index, new_index);
                    }
                }
            }
        }

        self.context(self.min_context).union2.summ_freq = @intCast(
            sum_frequency + escape_frequency - (escape_frequency >> 1),
        );
        self.found_state = self.context(self.min_context).union4.stats;
    }

    pub fn makeEscFreq(self: *Model, num_masked: u32, escape_frequency: *u32) SeeSource {
        const stats_count = @as(u32, self.context(self.min_context).num_stats);
        if (stats_count == 256) {
            escape_frequency.* = 1;
            return .dummy;
        }

        const non_masked = stats_count - num_masked;
        const row: usize = self.ns2index[non_masked - 1];
        const min_context_record = self.context(self.min_context);
        const suffix_stats_count = @as(u32, self.context(min_context_record.suffix).num_stats);
        const sum_frequency = @as(u32, min_context_record.union2.summ_freq);
        // PPMd7 and Variant H specify unsigned subtraction here. When the
        // suffix has fewer states, wraparound makes this comparison true.
        const suffix_delta = suffix_stats_count -% stats_count;
        const column = @as(usize, @intFromBool(non_masked < suffix_delta)) +
            2 * @as(usize, @intFromBool(sum_frequency < 11 * stats_count)) +
            4 * @as(usize, @intFromBool(num_masked > non_masked)) + self.hi_bits_flag;
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
        var state_offset = self.found_state;
        const frequency = @as(u32, self.state(state_offset).freq) + 4;
        self.context(self.min_context).union2.summ_freq += 4;
        self.state(state_offset).freq = @intCast(frequency);
        const previous = Offset{ .value = state_offset.value - @sizeOf(State) };
        if (frequency > self.state(previous).freq) {
            self.swapStates(state_offset);
            state_offset = previous;
            self.found_state = state_offset;
            if (frequency > max_frequency) self.rescale();
        }
        self.nextContext();
    }

    pub fn update1_0(self: *Model) void {
        const selected = self.state(self.found_state);
        const context_record = self.context(self.min_context);
        var frequency = @as(u32, selected.freq);
        const sum_frequency = @as(u32, context_record.union2.summ_freq);
        self.prev_success = @intFromBool(2 * frequency > sum_frequency);
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

    pub fn updateBin(self: *Model, state_offset: Offset) void {
        const selected = self.state(state_offset);
        const frequency = @as(u32, selected.freq);
        self.found_state = state_offset;
        self.prev_success = 1;
        self.run_length += 1;
        selected.freq += @intFromBool(frequency < 128);
        self.nextContext();
    }

    pub fn getBinSumm(self: *Model) *u16 {
        const selected = self.singleState(self.min_context);
        const high_bits_found = hiBitsFlag3(self.state(self.found_state).symbol);
        const high_bits_selected = hiBitsFlag4(selected.symbol);
        self.hi_bits_flag = high_bits_found;
        const suffix_stats = self.context(self.context(self.min_context).suffix).num_stats;
        const context_index = self.prev_success +
            ((@as(u32, @bitCast(self.run_length)) >> 26) & 0x20) +
            self.ns2bs_index[suffix_stats - 1] + high_bits_selected + high_bits_found;
        return &self.bin_summ[selected.freq - 1][context_index];
    }

    pub fn hiBitsFlag3(symbol: u8) u32 {
        return (@as(u32, symbol) + 0xc0) >> 5 & 8;
    }

    fn hiBitsFlag4(symbol: u8) u32 {
        return (@as(u32, symbol) + 0xc0) >> 4 & 16;
    }
};

comptime {
    if (@sizeOf(See) != 4) @compileError("PPMd7 See must be four bytes");
    if (@sizeOf(State) != 6) @compileError("PPMd7 State must be six bytes");
    if (@sizeOf(State2) != 2) @compileError("PPMd7 State2 must be two bytes");
    if (@sizeOf(State4) != 4) @compileError("PPMd7 State4 must be four bytes");
    if (@sizeOf(Context) != unit_size) @compileError("PPMd7 Context must be one unit");
    if (@sizeOf(Node) != unit_size) @compileError("PPMd7 Node must be one unit");
}

test "PPMd7 packed layouts and offsets are bounded" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(See));
    try std.testing.expectEqual(@as(usize, 6), @sizeOf(State));
    try std.testing.expectEqual(unit_size, @sizeOf(Context));
    try std.testing.expectEqual(unit_size, @sizeOf(Node));
    try std.testing.expect(!Offset.null_offset.isValidFor(64, Context));
    try std.testing.expect(Offset.init(12).isValidFor(64, Context));
    try std.testing.expect(!Offset.init(60).isValidFor(64, Context));
    try std.testing.expect(!Offset.init(13).isValidFor(64, Context));
}

test "PPMd7 minimum model initializes root and free-list round trip" {
    var model = try Model.init(std.testing.allocator, min_order, min_memory_size);
    defer model.deinit();

    const root = model.context(model.min_context);
    try std.testing.expectEqual(@as(u16, 256), root.num_stats);
    try std.testing.expectEqual(@as(u16, 257), root.union2.summ_freq);
    try std.testing.expect(root.suffix.isNull());
    try std.testing.expect(model.lo_unit <= model.hi_unit);
    try std.testing.expect(model.text < model.units_start);
    for (0..256) |symbol| {
        const state = model.stateAt(root.union4.stats, symbol);
        try std.testing.expectEqual(@as(u8, @intCast(symbol)), state.symbol);
        try std.testing.expectEqual(@as(u8, 1), state.freq);
        try std.testing.expect(state.successor().isNull());
    }

    const block = model.allocUnits(0) orelse return error.TestUnexpectedResult;
    model.insertNode(block, 0);
    try std.testing.expectEqual(block.value, model.removeNode(0).value);
    try std.testing.expect(model.free_list[0].isNull());
}

test "PPMd7 rejects invalid model limits" {
    try std.testing.expectError(
        error.InvalidPpmdOrder,
        Model.init(std.testing.allocator, min_order - 1, min_memory_size),
    );
    try std.testing.expectError(
        error.InvalidPpmdOrder,
        Model.init(std.testing.allocator, max_order + 1, min_memory_size),
    );
    try std.testing.expectError(
        error.InvalidPpmdMemorySize,
        Model.init(std.testing.allocator, min_order, min_memory_size - 1),
    );
}
