const std = @import("std");
const model_mod = @import("model.zig");

pub const Error = model_mod.Error || error{
    InvalidPpmdData,
    TruncatedPpmdInput,
    PpmdTrailingData,
    SizeMismatch,
};

const top_value: u32 = 1 << 24;
const bottom_value: u32 = 1 << 15;

const RangeDecoder = struct {
    input: []const u8,
    position: usize = 0,
    range: u32 = std.math.maxInt(u32),
    code: u32 = 0,
    low: u32 = 0,

    fn init(input: []const u8) Error!RangeDecoder {
        var result = RangeDecoder{ .input = input };
        for (0..4) |_| result.code = result.code *% 256 | try result.readByte();
        if (result.code == std.math.maxInt(u32)) return error.InvalidPpmdData;
        return result;
    }

    fn readByte(self: *RangeDecoder) Error!u8 {
        if (self.position == self.input.len) return error.TruncatedPpmdInput;
        const result = self.input[self.position];
        self.position += 1;
        return result;
    }

    fn correctSum(self: *const RangeDecoder, sum: u32) u32 {
        return @min(sum, self.range);
    }

    fn threshold(self: *RangeDecoder, total: u32) Error!u32 {
        if (total == 0) return error.InvalidPpmdData;
        self.range /= total;
        if (self.range == 0) return error.InvalidPpmdData;
        return self.code / self.range;
    }

    fn decode(self: *RangeDecoder, start: u32, size: u32) Error!void {
        if (size == 0) return error.InvalidPpmdData;
        const scaled_start = start * self.range;
        if (scaled_start > self.code) return error.InvalidPpmdData;
        self.low +%= scaled_start;
        self.code -= scaled_start;
        self.range *= size;
    }

    fn decodeFinal(self: *RangeDecoder, start: u32, size: u32) Error!void {
        try self.decode(start, size);
        try self.normalize();
    }

    fn decodeBit1(self: *RangeDecoder, bound: u32) Error!void {
        if (bound > self.code) return error.InvalidPpmdData;
        self.low +%= bound;
        self.code -= bound;
        self.range = (self.range & ~(model_mod.bin_scale - 1)) -% bound;
        if (self.range == 0) return error.InvalidPpmdData;
    }

    fn normalize(self: *RangeDecoder) Error!void {
        while (true) {
            var needed = (self.low ^ (self.low +% self.range)) < top_value;
            if (!needed and self.range < bottom_value) {
                self.range = (0 -% self.low) & (bottom_value - 1);
                needed = true;
            }
            if (!needed) return;
            self.code = self.code *% 256 | try self.readByte();
            self.range *%= 256;
            self.low *%= 256;
        }
    }
};

pub fn decodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    order: u8,
    memory_size: u32,
    restore_method: model_mod.RestoreMethod,
) Error!void {
    var range_decoder = try RangeDecoder.init(input);
    var model = try model_mod.Model.init(allocator, order, memory_size, restore_method);
    defer model.deinit();
    for (output) |*byte|
        byte.* = (try decodeSymbol(&model, &range_decoder)) orelse return error.SizeMismatch;
    if (try decodeSymbol(&model, &range_decoder) != null) return error.SizeMismatch;
    if (range_decoder.code != 0) return error.InvalidPpmdData;
    if (range_decoder.position != input.len) return error.PpmdTrailingData;
}

fn decodeSymbol(model: *model_mod.Model, range_decoder: *RangeDecoder) Error!?u8 {
    var symbol_mask: [256]u8 = undefined;
    const min_context = model.context(model.min_context);
    if (min_context.num_stats != 0) {
        const total = range_decoder.correctSum(min_context.union2.summ_freq);
        var count = try range_decoder.threshold(total);
        const original_count = count;
        var state_offset = min_context.union4.stats;
        for (0..@as(usize, min_context.num_stats) + 1) |index| {
            const selected = model.state(state_offset);
            if (count < selected.freq) {
                try range_decoder.decodeFinal(original_count - count, selected.freq);
                model.found_state = state_offset;
                const symbol = selected.symbol;
                if (index == 0)
                    model.update1_0()
                else {
                    model.prev_success = 0;
                    model.update1();
                }
                return symbol;
            }
            count -= selected.freq;
            state_offset.value += @sizeOf(model_mod.State);
        }
        model.prev_success = 0;
        if (original_count >= total) return error.InvalidPpmdData;
        const symbol_frequency = original_count - count;
        try range_decoder.decode(symbol_frequency, total - symbol_frequency);
        @memset(&symbol_mask, std.math.maxInt(u8));
        state_offset = min_context.union4.stats;
        for (0..@as(usize, min_context.num_stats) + 1) |_| {
            symbol_mask[model.state(state_offset).symbol] = 0;
            state_offset.value += @sizeOf(model_mod.State);
        }
    } else {
        const state_offset = model_mod.Offset.init(
            @as(usize, model.min_context.value) + @offsetOf(model_mod.Context, "union2"),
        );
        const selected = model.state(state_offset);
        const probability = model.getBinSumm();
        var value = @as(u32, probability.*);
        const bound = (range_decoder.range >> 14) * value;
        value -= (value + (1 << (model_mod.period_bits - 2))) >> model_mod.period_bits;
        if (range_decoder.code < bound) {
            probability.* = @intCast(value + (1 << model_mod.int_bits));
            range_decoder.range = bound;
            try range_decoder.normalize();
            return model.updateBin(state_offset);
        }
        probability.* = @intCast(value);
        model.init_esc = model_mod.expEscape(value >> 10);
        try range_decoder.decodeBit1(bound);
        @memset(&symbol_mask, std.math.maxInt(u8));
        symbol_mask[selected.symbol] = 0;
        model.prev_success = 0;
    }

    while (true) {
        try range_decoder.normalize();
        var context_offset = model.min_context;
        const masked_count = @as(u32, model.context(context_offset).num_stats);
        while (true) {
            model.order_fall += 1;
            const suffix = model.context(context_offset).suffix;
            if (suffix.isNull()) return null;
            context_offset = suffix;
            if (model.context(context_offset).num_stats != masked_count) break;
        }
        model.min_context = context_offset;
        const context = model.context(context_offset);
        var non_masked_frequency: u32 = 0;
        var state_offset = context.union4.stats;
        for (0..@as(usize, context.num_stats) + 1) |_| {
            const selected = model.state(state_offset);
            non_masked_frequency += @as(u32, selected.freq & symbol_mask[selected.symbol]);
            state_offset.value += @sizeOf(model_mod.State);
        }
        var escape_frequency: u32 = 0;
        const see_source = model.makeEscFreq(masked_count, &escape_frequency);
        const frequency_sum = non_masked_frequency + escape_frequency;
        const corrected_sum = range_decoder.correctSum(frequency_sum);
        var count = try range_decoder.threshold(corrected_sum);
        if (count < non_masked_frequency) {
            const original_count = count;
            state_offset = context.union4.stats;
            while (true) {
                const selected = model.state(state_offset);
                const frequency = @as(u32, selected.freq & symbol_mask[selected.symbol]);
                if (count < frequency) {
                    try range_decoder.decodeFinal(original_count - count, frequency);
                    model.getSee(see_source).update();
                    model.found_state = state_offset;
                    const symbol = selected.symbol;
                    model.update2();
                    return symbol;
                }
                count -= frequency;
                state_offset.value += @sizeOf(model_mod.State);
            }
        }
        if (count >= corrected_sum or corrected_sum < non_masked_frequency)
            return error.InvalidPpmdData;
        try range_decoder.decode(non_masked_frequency, corrected_sum - non_masked_frequency);
        model.getSee(see_source).summ +%= @truncate(frequency_sum);
        state_offset = context.union4.stats;
        for (0..@as(usize, context.num_stats) + 1) |_| {
            symbol_mask[model.state(state_offset).symbol] = 0;
            state_offset.value += @sizeOf(model_mod.State);
        }
    }
}

test "PPMd8 range decoder rejects malformed initialization" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedPpmdInput,
        decodeInto(std.testing.allocator, &.{}, &output, 8, 1024 * 1024, .restart),
    );
    try std.testing.expectError(
        error.InvalidPpmdData,
        decodeInto(std.testing.allocator, &.{ 0xff, 0xff, 0xff, 0xff }, &output, 8, 1024 * 1024, .restart),
    );
}
