const std = @import("std");
const core = @import("../core.zig");
const model_mod = @import("../seven_zip/ppmd7/model.zig");

pub const Error = core.Error || model_mod.Error || error{
    InvalidRarPpmd,
    RarPpmdMemoryLimitExceeded,
};

const top_value: u32 = 1 << 24;
const bottom_value: u32 = 1 << 15;

const RangeDecoder = struct {
    range: u32 = std.math.maxInt(u32),
    code: u32 = 0,
    low: u32 = 0,

    fn init(self: *RangeDecoder, input: []const u8, position: *usize) Error!void {
        self.* = .{};
        for (0..4) |_| self.code = (self.code << 8) | try readByte(input, position);
        if (self.code == std.math.maxInt(u32)) return error.InvalidRarPpmd;
    }

    fn threshold(self: *RangeDecoder, total: u32) Error!u32 {
        if (total == 0) return error.InvalidRarPpmd;
        self.range /= total;
        if (self.range == 0) return error.InvalidRarPpmd;
        return (self.code -% self.low) / self.range;
    }

    fn decode(self: *RangeDecoder, start: u32, size: u32) Error!void {
        if (size == 0) return error.InvalidRarPpmd;
        self.low +%= start *% self.range;
        self.range *%= size;
        if (self.range == 0) return error.InvalidRarPpmd;
    }

    fn decodeFinal(
        self: *RangeDecoder,
        start: u32,
        size: u32,
        input: []const u8,
        position: *usize,
    ) Error!void {
        try self.decode(start, size);
        try self.normalize(input, position);
    }

    fn decodeBit0(self: *RangeDecoder, size: u32) Error!void {
        if (size == 0) return error.InvalidRarPpmd;
        self.range = size;
    }

    fn decodeBit1(self: *RangeDecoder, size: u32) Error!void {
        self.low +%= size;
        self.range = (self.range & ~(model_mod.bin_scale - 1)) -% size;
        if (self.range == 0) return error.InvalidRarPpmd;
    }

    fn normalize(self: *RangeDecoder, input: []const u8, position: *usize) Error!void {
        while (true) {
            var needed = (self.low ^ (self.low +% self.range)) < top_value;
            if (!needed and self.range < bottom_value) {
                self.range = (0 -% self.low) & (bottom_value - 1);
                needed = true;
            }
            if (!needed) return;
            self.code = self.code *% 256 | try readByte(input, position);
            self.range *%= 256;
            self.low *%= 256;
        }
    }
};

pub const Session = struct {
    allocator: std.mem.Allocator,
    model: ?model_mod.Model = null,
    range: RangeDecoder = .{},
    escape: u8 = 2,
    position: usize = 0,

    pub fn init(allocator: std.mem.Allocator) Session {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Session) void {
        if (self.model) |*model| model.deinit();
        self.* = undefined;
    }

    pub fn startBlock(
        self: *Session,
        first_byte: u8,
        input: []const u8,
        position: usize,
        max_memory_size: usize,
    ) Error!void {
        self.position = position;
        const reset = first_byte & 0x20 != 0;
        const memory_byte = if (reset) try readByte(input, &self.position) else 0;
        if (first_byte & 0x40 != 0) self.escape = try readByte(input, &self.position);
        try self.range.init(input, &self.position);
        if (reset) {
            var order: usize = (first_byte & 0x1f) + 1;
            if (order > 16) order = 16 + (order - 16) * 3;
            if (order < model_mod.min_order or order > model_mod.max_order)
                return error.InvalidRarPpmd;
            const memory_size = (@as(usize, memory_byte) + 1) * 1024 * 1024;
            if (memory_size > max_memory_size) return error.RarPpmdMemoryLimitExceeded;
            if (self.model) |*old| old.deinit();
            self.model = null;
            self.model = try model_mod.Model.init(
                self.allocator,
                @intCast(order),
                @intCast(memory_size),
            );
        } else if (self.model == null) {
            return error.InvalidRarPpmd;
        }
    }

    pub fn decodeSymbol(self: *Session, input: []const u8) Error!?u8 {
        const model = if (self.model) |*value| value else return error.InvalidRarPpmd;
        var symbol_mask: [256]u8 = undefined;
        const min_context = model.context(model.min_context);
        if (min_context.num_stats != 1) {
            var state_offset = min_context.union4.stats;
            const sum_frequency = @as(u32, min_context.union2.summ_freq);
            var count = try self.range.threshold(sum_frequency);
            const original_count = count;
            var selected = model.state(state_offset);
            if (count < selected.freq) {
                try self.range.decodeFinal(0, selected.freq, input, &self.position);
                model.found_state = state_offset;
                const symbol = selected.symbol;
                model.update1_0();
                return symbol;
            }
            count -= selected.freq;
            model.prev_success = 0;
            var remaining = @as(usize, min_context.num_stats) - 1;
            while (remaining != 0) : (remaining -= 1) {
                state_offset.value += @sizeOf(model_mod.State);
                selected = model.state(state_offset);
                if (count < selected.freq) {
                    try self.range.decodeFinal(
                        original_count - count,
                        selected.freq,
                        input,
                        &self.position,
                    );
                    model.found_state = state_offset;
                    const symbol = selected.symbol;
                    model.update1();
                    return symbol;
                }
                count -= selected.freq;
            }
            if (original_count >= sum_frequency) return error.InvalidRarPpmd;
            const encoded_frequency = original_count - count;
            try self.range.decode(encoded_frequency, sum_frequency - encoded_frequency);
            model.hi_bits_flag = model_mod.Model.hiBitsFlag3(model.state(model.found_state).symbol);
            @memset(&symbol_mask, std.math.maxInt(u8));
            var masked_offset = min_context.union4.stats;
            for (0..min_context.num_stats) |_| {
                symbol_mask[model.state(masked_offset).symbol] = 0;
                masked_offset.value += @sizeOf(model_mod.State);
            }
        } else {
            const state_offset = model_mod.Offset.init(
                @as(usize, model.min_context.value) + @offsetOf(model_mod.Context, "union2"),
            );
            const selected = model.state(state_offset);
            const probability = model.getBinSumm();
            var value = @as(u32, probability.*);
            const size0 = (self.range.range >> 14) * value;
            value -= (value + (1 << (model_mod.period_bits - 2))) >> model_mod.period_bits;
            if (self.range.code -% self.range.low < size0) {
                probability.* = @intCast(value + (1 << model_mod.int_bits));
                try self.range.decodeBit0(size0);
                try self.range.normalize(input, &self.position);
                const symbol = selected.symbol;
                model.updateBin(state_offset);
                return symbol;
            }
            probability.* = @intCast(value);
            model.init_esc = model_mod.expEscape(value >> 10);
            try self.range.decodeBit1(size0);
            @memset(&symbol_mask, std.math.maxInt(u8));
            symbol_mask[selected.symbol] = 0;
            model.prev_success = 0;
        }

        while (true) {
            try self.range.normalize(input, &self.position);
            var context_offset = model.min_context;
            const masked_count = @as(u32, model.context(context_offset).num_stats);
            while (model.context(context_offset).num_stats == masked_count) {
                model.order_fall += 1;
                const suffix = model.context(context_offset).suffix;
                if (suffix.isNull()) return null;
                context_offset = suffix;
            }
            model.min_context = context_offset;
            const context = model.context(context_offset);
            var high_count: u32 = 0;
            var state_offset = context.union4.stats;
            for (0..context.num_stats) |_| {
                const state = model.state(state_offset);
                high_count += @as(u32, state.freq & symbol_mask[state.symbol]);
                state_offset.value += @sizeOf(model_mod.State);
            }
            var escape_frequency: u32 = 0;
            const see_source = model.makeEscFreq(masked_count, &escape_frequency);
            const frequency_sum = high_count + escape_frequency;
            var count = try self.range.threshold(frequency_sum);
            if (count < high_count) {
                const original_count = count;
                state_offset = context.union4.stats;
                while (true) {
                    const state = model.state(state_offset);
                    const frequency = @as(u32, state.freq & symbol_mask[state.symbol]);
                    if (count < frequency) {
                        try self.range.decodeFinal(
                            original_count - count,
                            frequency,
                            input,
                            &self.position,
                        );
                        model.getSee(see_source).update();
                        model.found_state = state_offset;
                        const symbol = state.symbol;
                        model.update2();
                        return symbol;
                    }
                    count -= frequency;
                    state_offset.value += @sizeOf(model_mod.State);
                }
            }
            if (count >= frequency_sum) return error.InvalidRarPpmd;
            try self.range.decode(high_count, frequency_sum - high_count);
            model.getSee(see_source).summ +%= @truncate(frequency_sum);
            state_offset = context.union4.stats;
            for (0..context.num_stats) |_| {
                symbol_mask[model.state(state_offset).symbol] = 0;
                state_offset.value += @sizeOf(model_mod.State);
            }
        }
    }
};

fn readByte(input: []const u8, position: *usize) Error!u8 {
    if (position.* == input.len) return error.TruncatedFrame;
    const byte = input[position.*];
    position.* += 1;
    return byte;
}

test "RAR PPMd-H rejects invalid initialization and memory limits" {
    var session = Session.init(std.testing.allocator);
    defer session.deinit();
    try std.testing.expectError(
        error.TruncatedFrame,
        session.startBlock(0x20 | 1, &.{}, 0, 64 * 1024 * 1024),
    );
    try std.testing.expectError(
        error.RarPpmdMemoryLimitExceeded,
        session.startBlock(0x20 | 1, &.{ 63, 0, 0, 0, 0 }, 0, 32 * 1024 * 1024),
    );

    var failing = Session.init(std.testing.failing_allocator);
    defer failing.deinit();
    try std.testing.expectError(
        error.OutOfMemory,
        failing.startBlock(0x20 | 1, &.{ 0, 0, 0, 0, 0 }, 0, 1024 * 1024),
    );
    try std.testing.expect(failing.model == null);
}
