const std = @import("std");
const model_mod = @import("model.zig");

pub const Error = model_mod.Error;

const top_value: u32 = 1 << 24;
const bottom_value: u32 = 1 << 15;

const RangeEncoder = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    range: u32 = std.math.maxInt(u32),
    low: u32 = 0,

    fn correctSum(self: *const RangeEncoder, sum: u32) u32 {
        return @min(sum, self.range);
    }

    fn encode(self: *RangeEncoder, start: u32, size: u32, total: u32) void {
        self.range /= total;
        self.low +%= start * self.range;
        self.range *= size;
    }

    fn encodeFinal(self: *RangeEncoder, start: u32, size: u32, total: u32) Error!void {
        self.encode(start, size, total);
        try self.normalize();
    }

    fn encodeBit1(self: *RangeEncoder, bound: u32) void {
        self.low +%= bound;
        self.range = (self.range & ~(model_mod.bin_scale - 1)) -% bound;
    }

    fn normalize(self: *RangeEncoder) Error!void {
        while (true) {
            var needed = (self.low ^ (self.low +% self.range)) < top_value;
            if (!needed and self.range < bottom_value) {
                self.range = (0 -% self.low) & (bottom_value - 1);
                needed = true;
            }
            if (!needed) return;
            try self.output.append(self.allocator, @truncate(self.low >> 24));
            self.range *%= 256;
            self.low *%= 256;
        }
    }

    fn finish(self: *RangeEncoder) Error!void {
        for (0..4) |_| {
            try self.output.append(self.allocator, @truncate(self.low >> 24));
            self.low *%= 256;
        }
    }
};

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    order: u8,
    memory_size: u32,
    restore_method: model_mod.RestoreMethod,
) Error!usize {
    const output_start = output.items.len;
    errdefer output.items.len = output_start;
    var model = try model_mod.Model.init(allocator, order, memory_size, restore_method);
    defer model.deinit();
    var range_encoder = RangeEncoder{ .allocator = allocator, .output = output };
    for (input) |symbol| try encodeSymbol(&model, &range_encoder, symbol);
    try encodeSymbol(&model, &range_encoder, null);
    try range_encoder.finish();
    return output.items.len - output_start;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    order: u8,
    memory_size: u32,
    restore_method: model_mod.RestoreMethod,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, order, memory_size, restore_method);
    return output.toOwnedSlice(allocator);
}

fn encodeSymbol(
    model: *model_mod.Model,
    range_encoder: *RangeEncoder,
    symbol: ?u8,
) Error!void {
    var symbol_mask: [256]u8 = undefined;
    const min_context = model.context(model.min_context);
    if (min_context.num_stats != 0) {
        const total = range_encoder.correctSum(min_context.union2.summ_freq);
        var sum: u32 = 0;
        var state_offset = min_context.union4.stats;
        for (0..@as(usize, min_context.num_stats) + 1) |index| {
            const selected = model.state(state_offset);
            if (symbol != null and selected.symbol == symbol.?) {
                try range_encoder.encodeFinal(sum, selected.freq, total);
                model.found_state = state_offset;
                if (index == 0) {
                    model.update1_0();
                } else {
                    model.prev_success = 0;
                    model.update1();
                }
                return;
            }
            sum += selected.freq;
            state_offset.value += @sizeOf(model_mod.State);
        }
        model.prev_success = 0;
        range_encoder.encode(sum, total - sum, total);
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
        const bound = (range_encoder.range >> 14) * value;
        value -= (value + (1 << (model_mod.period_bits - 2))) >> model_mod.period_bits;
        if (symbol != null and selected.symbol == symbol.?) {
            probability.* = @intCast(value + (1 << model_mod.int_bits));
            range_encoder.range = bound;
            try range_encoder.normalize();
            _ = model.updateBin(state_offset);
            return;
        }
        probability.* = @intCast(value);
        model.init_esc = model_mod.expEscape(value >> 10);
        range_encoder.encodeBit1(bound);
        @memset(&symbol_mask, std.math.maxInt(u8));
        symbol_mask[selected.symbol] = 0;
        model.prev_success = 0;
    }

    while (true) {
        try range_encoder.normalize();
        var context_offset = model.min_context;
        const masked_count = @as(u32, model.context(context_offset).num_stats);
        while (true) {
            model.order_fall += 1;
            const suffix = model.context(context_offset).suffix;
            if (suffix.isNull()) return;
            context_offset = suffix;
            if (model.context(context_offset).num_stats != masked_count) break;
        }
        model.min_context = context_offset;
        const context = model.context(context_offset);
        var escape_frequency: u32 = 0;
        const see_source = model.makeEscFreq(masked_count, &escape_frequency);
        var non_masked_frequency: u32 = 0;
        var selected_offset: ?model_mod.Offset = null;
        var selected_frequency: u32 = 0;
        var selected_low: u32 = 0;
        var state_offset = context.union4.stats;
        for (0..@as(usize, context.num_stats) + 1) |_| {
            const selected = model.state(state_offset);
            const frequency = @as(u32, selected.freq & symbol_mask[selected.symbol]);
            if (symbol != null and selected.symbol == symbol.?) {
                selected_offset = state_offset;
                selected_frequency = frequency;
                selected_low = non_masked_frequency;
            }
            non_masked_frequency += frequency;
            state_offset.value += @sizeOf(model_mod.State);
        }
        const uncorrected_total = non_masked_frequency + escape_frequency;
        const total = range_encoder.correctSum(uncorrected_total);
        if (selected_offset) |selected| {
            std.debug.assert(selected_frequency != 0);
            model.getSee(see_source).update();
            try range_encoder.encodeFinal(selected_low, selected_frequency, total);
            model.found_state = selected;
            model.update2();
            return;
        }
        model.getSee(see_source).summ +%= @truncate(uncorrected_total);
        range_encoder.encode(non_masked_frequency, total -% non_masked_frequency, total);
        state_offset = context.union4.stats;
        for (0..@as(usize, context.num_stats) + 1) |_| {
            symbol_mask[model.state(state_offset).symbol] = 0;
            state_offset.value += @sizeOf(model_mod.State);
        }
    }
}

test "PPMd8 encoder round trips restart and cut-off modes" {
    const decoder = @import("decoder.zig");
    const input = ("PPMd8 model payload\n" ** 1024) ++ ("0123456789abcdef\n" ** 1024);
    inline for (.{ model_mod.RestoreMethod.restart, .cut_off }) |restore_method| {
        const encoded = try encodeAlloc(
            std.testing.allocator,
            input,
            8,
            64 * 1024,
            restore_method,
        );
        defer std.testing.allocator.free(encoded);
        const output = try std.testing.allocator.alloc(u8, input.len);
        defer std.testing.allocator.free(output);
        try decoder.decodeInto(
            std.testing.allocator,
            encoded,
            output,
            8,
            64 * 1024,
            restore_method,
        );
        try std.testing.expectEqualSlices(u8, input, output);
    }
}
