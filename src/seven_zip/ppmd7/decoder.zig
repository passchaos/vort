const std = @import("std");
const model_mod = @import("model.zig");

pub const Error = model_mod.Error || error{
    InvalidPpmdData,
    TruncatedPpmdInput,
    PpmdTrailingData,
};

const top_value: u32 = 1 << 24;

const RangeDecoder = struct {
    input: []const u8,
    position: usize = 0,
    range: u32 = std.math.maxInt(u32),
    code: u32 = 0,

    fn init(input: []const u8) Error!RangeDecoder {
        var result = RangeDecoder{ .input = input };
        if (try result.readByte() != 0) return error.InvalidPpmdData;
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

    fn threshold(self: *RangeDecoder, total: u32) Error!u32 {
        if (total == 0) return error.InvalidPpmdData;
        self.range /= total;
        if (self.range == 0) return error.InvalidPpmdData;
        return self.code / self.range;
    }

    fn decode(self: *RangeDecoder, start: u32, size: u32) Error!void {
        if (size == 0) return error.InvalidPpmdData;
        const low = start * self.range;
        if (low > self.code) return error.InvalidPpmdData;
        self.code -= low;
        self.range *= size;
    }

    fn decodeFinal(self: *RangeDecoder, start: u32, size: u32) Error!void {
        try self.decode(start, size);
        try self.normalizeRemote();
    }

    fn decodeBit0(self: *RangeDecoder, size: u32) Error!void {
        if (size == 0) return error.InvalidPpmdData;
        self.range = size;
        if (self.range < top_value) {
            self.code = self.code *% 256 | try self.readByte();
            self.range <<= 8;
        }
    }

    fn decodeBit1(self: *RangeDecoder, size: u32) Error!void {
        if (size > self.code or size >= self.range) return error.InvalidPpmdData;
        self.code -= size;
        self.range -= size;
    }

    fn normalizeRemote(self: *RangeDecoder) Error!void {
        if (self.range < top_value) {
            self.code = self.code *% 256 | try self.readByte();
            self.range <<= 8;
            if (self.range < top_value) {
                self.code = self.code *% 256 | try self.readByte();
                self.range <<= 8;
            }
        }
    }
};

pub fn decodeInto(
    allocator: std.mem.Allocator,
    input: []const u8,
    output: []u8,
    order: u8,
    memory_size: u32,
) Error!void {
    var range_decoder = try RangeDecoder.init(input);
    var model = try model_mod.Model.init(allocator, order, memory_size);
    defer model.deinit();

    for (output) |*byte| byte.* = try decodeSymbol(&model, &range_decoder);
    if (range_decoder.code != 0) return error.InvalidPpmdData;
    if (range_decoder.position != input.len) return error.PpmdTrailingData;
}

fn decodeSymbol(model: *model_mod.Model, range_decoder: *RangeDecoder) Error!u8 {
    var symbol_mask: [256]u8 = undefined;
    const min_context = model.context(model.min_context);
    if (min_context.num_stats != 1) {
        var state_offset = min_context.union4.stats;
        const sum_frequency = @as(u32, min_context.union2.summ_freq);
        var count = try range_decoder.threshold(sum_frequency);
        const high_count = count;
        var selected = model.state(state_offset);
        if (count < selected.freq) {
            try range_decoder.decodeFinal(0, selected.freq);
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
                try range_decoder.decodeFinal(high_count - count, selected.freq);
                model.found_state = state_offset;
                const symbol = selected.symbol;
                model.update1();
                return symbol;
            }
            count -= selected.freq;
        }
        if (high_count >= sum_frequency) return error.InvalidPpmdData;
        const encoded_frequency = high_count - count;
        try range_decoder.decode(encoded_frequency, sum_frequency - encoded_frequency);
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
        const size0 = (range_decoder.range >> 14) * value;
        value -= (value + (1 << (model_mod.period_bits - 2))) >> model_mod.period_bits;
        if (range_decoder.code < size0) {
            probability.* = @intCast(value + (1 << model_mod.int_bits));
            try range_decoder.decodeBit0(size0);
            const symbol = selected.symbol;
            model.updateBin(state_offset);
            return symbol;
        }

        probability.* = @intCast(value);
        model.init_esc = model_mod.expEscape(value >> 10);
        try range_decoder.decodeBit1(size0);
        @memset(&symbol_mask, std.math.maxInt(u8));
        symbol_mask[selected.symbol] = 0;
        model.prev_success = 0;
    }

    while (true) {
        try range_decoder.normalizeRemote();
        var context_offset = model.min_context;
        const masked_count = @as(u32, model.context(context_offset).num_stats);
        while (model.context(context_offset).num_stats == masked_count) {
            model.order_fall += 1;
            const suffix = model.context(context_offset).suffix;
            if (suffix.isNull()) return error.InvalidPpmdData;
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
        var count = try range_decoder.threshold(frequency_sum);
        if (count < high_count) {
            const original_count = count;
            state_offset = context.union4.stats;
            while (true) {
                const state = model.state(state_offset);
                const frequency = @as(u32, state.freq & symbol_mask[state.symbol]);
                if (count < frequency) {
                    try range_decoder.decodeFinal(original_count - count, frequency);
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
        if (count >= frequency_sum) return error.InvalidPpmdData;
        try range_decoder.decode(high_count, frequency_sum - high_count);
        const see = model.getSee(see_source);
        see.summ +%= @truncate(frequency_sum);

        state_offset = context.union4.stats;
        for (0..context.num_stats) |_| {
            symbol_mask[model.state(state_offset).symbol] = 0;
            state_offset.value += @sizeOf(model_mod.State);
        }
    }
}

test "PPMd7 range decoder rejects malformed initialization and truncation" {
    var output: [1]u8 = undefined;
    try std.testing.expectError(
        error.TruncatedPpmdInput,
        decodeInto(std.testing.allocator, &.{}, &output, 4, model_mod.min_memory_size),
    );
    try std.testing.expectError(
        error.InvalidPpmdData,
        decodeInto(std.testing.allocator, &.{ 1, 0, 0, 0, 0 }, &output, 4, model_mod.min_memory_size),
    );
    try std.testing.expectError(
        error.InvalidPpmdData,
        decodeInto(std.testing.allocator, &.{ 0, 0xff, 0xff, 0xff, 0xff }, &output, 4, model_mod.min_memory_size),
    );
}

test "PPMd7 empty payload requires a finished range and exact input" {
    try decodeInto(std.testing.allocator, &.{ 0, 0, 0, 0, 0 }, &.{}, 4, model_mod.min_memory_size);
    try std.testing.expectError(
        error.PpmdTrailingData,
        decodeInto(std.testing.allocator, &.{ 0, 0, 0, 0, 0, 0 }, &.{}, 4, model_mod.min_memory_size),
    );
}

test "PPMd7 decodes a 7-Zip range-coded payload and rejects corruption" {
    const encoded = [_]u8{
        0x00, 0x73, 0x02, 0x14, 0x49, 0xc6, 0x00, 0x2c,
        0x4c, 0x7f, 0xcc, 0x8f, 0xf0, 0xb0, 0x74, 0x5b,
        0x24, 0x9d, 0xa3, 0x94, 0x7b, 0xcf, 0x29, 0xdb,
        0xf7, 0xa3, 0xf8, 0x00,
    };
    const expected = "src/br/dictionary.bin binary\n";
    var output: [expected.len]u8 = undefined;
    try decodeInto(std.testing.allocator, &encoded, &output, 6, 64 * 1024);
    try std.testing.expectEqualSlices(u8, expected, &output);

    try std.testing.expectError(
        error.TruncatedPpmdInput,
        decodeInto(std.testing.allocator, encoded[0 .. encoded.len - 1], &output, 6, 64 * 1024),
    );
    var corrupt = encoded;
    corrupt[7] ^= 0x80;
    if (decodeInto(std.testing.allocator, &corrupt, &output, 6, 64 * 1024)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expect(err == error.InvalidPpmdData or err == error.TruncatedPpmdInput);
    }
}
