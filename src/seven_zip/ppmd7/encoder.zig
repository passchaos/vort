const std = @import("std");
const model_mod = @import("model.zig");

pub const Error = model_mod.Error;

const top_value: u32 = 1 << 24;

const RangeEncoder = struct {
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    range: u32 = std.math.maxInt(u32),
    low: u64 = 0,
    cache: u8 = 0,
    cache_size: u64 = 1,

    fn shiftLow(self: *RangeEncoder) Error!void {
        if (self.low < 0xff00_0000 or self.low >> 32 != 0) {
            var pending = self.cache;
            const carry: u8 = @truncate(self.low >> 32);
            while (true) {
                try self.output.append(self.allocator, pending +% carry);
                pending = 0xff;
                self.cache_size -= 1;
                if (self.cache_size == 0) break;
            }
            self.cache = @truncate(@as(u32, @truncate(self.low)) >> 24);
        }
        self.cache_size += 1;
        self.low = @as(u64, @as(u32, @truncate(self.low)) << 8);
    }

    fn encode(self: *RangeEncoder, start: u32, size: u32) void {
        self.low += @as(u64, start) * self.range;
        self.range *= size;
    }

    fn encodeFinal(self: *RangeEncoder, start: u32, size: u32) Error!void {
        self.encode(start, size);
        try self.normalizeRemote();
    }

    fn encodeBit0(self: *RangeEncoder, bound: u32) Error!void {
        self.range = bound;
        if (self.range < top_value) {
            self.range <<= 8;
            try self.shiftLow();
        }
    }

    fn encodeBit1(self: *RangeEncoder, bound: u32) void {
        self.low += bound;
        self.range -= bound;
    }

    fn normalizeRemote(self: *RangeEncoder) Error!void {
        if (self.range < top_value) {
            self.range <<= 8;
            try self.shiftLow();
            if (self.range < top_value) {
                self.range <<= 8;
                try self.shiftLow();
            }
        }
    }

    fn finish(self: *RangeEncoder) Error!void {
        for (0..5) |_| try self.shiftLow();
    }
};

pub fn encodeAppend(
    allocator: std.mem.Allocator,
    output: *std.ArrayList(u8),
    input: []const u8,
    order: u8,
    memory_size: u32,
) Error!usize {
    const output_start = output.items.len;
    errdefer output.items.len = output_start;

    var model = try model_mod.Model.init(allocator, order, memory_size);
    defer model.deinit();
    var range_encoder = RangeEncoder{ .allocator = allocator, .output = output };
    for (input) |symbol| try encodeSymbol(&model, &range_encoder, symbol);
    try range_encoder.finish();
    return output.items.len - output_start;
}

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    order: u8,
    memory_size: u32,
) Error![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    _ = try encodeAppend(allocator, &output, input, order, memory_size);
    return output.toOwnedSlice(allocator);
}

fn encodeSymbol(
    model: *model_mod.Model,
    range_encoder: *RangeEncoder,
    symbol: u8,
) Error!void {
    var symbol_mask: [256]u8 = undefined;
    const min_context = model.context(model.min_context);
    if (min_context.num_stats != 1) {
        range_encoder.range /= min_context.union2.summ_freq;
        var state_offset = min_context.union4.stats;
        var selected = model.state(state_offset);
        if (selected.symbol == symbol) {
            try range_encoder.encodeFinal(0, selected.freq);
            model.found_state = state_offset;
            model.update1_0();
            return;
        }

        model.prev_success = 0;
        var sum = @as(u32, selected.freq);
        for (1..min_context.num_stats) |_| {
            state_offset.value += @sizeOf(model_mod.State);
            selected = model.state(state_offset);
            if (selected.symbol == symbol) {
                try range_encoder.encodeFinal(sum, selected.freq);
                model.found_state = state_offset;
                model.update1();
                return;
            }
            sum += selected.freq;
        }
        range_encoder.encode(sum, @as(u32, min_context.union2.summ_freq) - sum);
        model.hi_bits_flag = model_mod.Model.hiBitsFlag3(model.state(model.found_state).symbol);
        @memset(&symbol_mask, std.math.maxInt(u8));
        state_offset = min_context.union4.stats;
        for (0..min_context.num_stats) |_| {
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
        if (selected.symbol == symbol) {
            probability.* = @intCast(value + (1 << model_mod.int_bits));
            try range_encoder.encodeBit0(bound);
            model.updateBin(state_offset);
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
        try range_encoder.normalizeRemote();
        var context_offset = model.min_context;
        const masked_count = @as(u32, model.context(context_offset).num_stats);
        while (true) {
            model.order_fall += 1;
            const suffix = model.context(context_offset).suffix;
            if (suffix.isNull()) unreachable;
            context_offset = suffix;
            if (model.context(context_offset).num_stats != masked_count) break;
        }
        model.min_context = context_offset;
        const context = model.context(context_offset);
        var escape_frequency: u32 = 0;
        const see_source = model.makeEscFreq(masked_count, &escape_frequency);

        var state_offset = context.union4.stats;
        var selected_offset: ?model_mod.Offset = null;
        var selected_frequency: u32 = 0;
        var selected_low: u32 = 0;
        var non_masked_frequency: u32 = 0;
        for (0..context.num_stats) |_| {
            const state = model.state(state_offset);
            const frequency = @as(u32, state.freq & symbol_mask[state.symbol]);
            if (state.symbol == symbol) {
                selected_offset = state_offset;
                selected_frequency = frequency;
                selected_low = non_masked_frequency;
            }
            non_masked_frequency += frequency;
            state_offset.value += @sizeOf(model_mod.State);
        }

        const total = non_masked_frequency + escape_frequency;
        range_encoder.range /= total;
        if (selected_offset) |selected| {
            std.debug.assert(selected_frequency != 0);
            model.getSee(see_source).update();
            try range_encoder.encodeFinal(selected_low, selected_frequency);
            model.found_state = selected;
            model.update2();
            return;
        }

        const see = model.getSee(see_source);
        see.summ +%= @truncate(total);
        range_encoder.encode(non_masked_frequency, escape_frequency);
        state_offset = context.union4.stats;
        for (0..context.num_stats) |_| {
            symbol_mask[model.state(state_offset).symbol] = 0;
            state_offset.value += @sizeOf(model_mod.State);
        }
    }
}

test "PPMd7 encoder matches a 7-Zip raw payload" {
    const input = "src/br/dictionary.bin binary\n";
    const expected = [_]u8{
        0x00, 0x73, 0x02, 0x14, 0x49, 0xc6, 0x00, 0x2c,
        0x4c, 0x7f, 0xcc, 0x8f, 0xf0, 0xb0, 0x74, 0x5b,
        0x24, 0x9d, 0xa3, 0x94, 0x7b, 0xcf, 0x29, 0xdb,
        0xf7, 0xa3, 0xf8, 0x00,
    };
    const encoded = try encodeAlloc(std.testing.allocator, input, 6, 64 * 1024);
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, &expected, encoded);
}

test "PPMd7 encoder round trips empty tiny and allocator-pressure payloads" {
    const decoder = @import("decoder.zig");
    const stress = ("PPMd allocator pressure and restart\n" ** 2048) ++
        ("0123456789abcdefghijklmnopqrstuvwxyz\n" ** 2048);
    inline for (.{ "", "a", "abracadabra", stress }) |input| {
        const encoded = try encodeAlloc(std.testing.allocator, input, 16, 64 * 1024);
        defer std.testing.allocator.free(encoded);
        const output = try std.testing.allocator.alloc(u8, input.len);
        defer std.testing.allocator.free(output);
        try decoder.decodeInto(std.testing.allocator, encoded, output, 16, 64 * 1024);
        try std.testing.expectEqualSlices(u8, input, output);
    }
}
