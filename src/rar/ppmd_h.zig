const std = @import("std");
const core = @import("../core.zig");
const model_mod = @import("../seven_zip/ppmd7/model.zig");

pub const Error = core.Error || model_mod.Error || error{
    InvalidRarPpmd,
    InvalidRarPpmdEncodeOptions,
    MissingRarPpmdSolidEncoderState,
    RarPpmdEncoderPoisoned,
    RarPpmdMemoryLimitExceeded,
};

const top_value: u32 = 1 << 24;
const bottom_value: u32 = 1 << 15;

pub const EncodeOptions = struct {
    order: u8 = 8,
    memory_size: usize = 25 * 1024 * 1024,
    escape: u8 = 2,
};

const RangeEncoder = struct {
    allocator: std.mem.Allocator,
    range: u32 = std.math.maxInt(u32),
    low: u32 = 0,
    bytes: std.ArrayList(u8) = .empty,

    fn deinit(self: *RangeEncoder) void {
        self.bytes.deinit(self.allocator);
        self.* = undefined;
    }

    fn encode(self: *RangeEncoder, start: u32, size: u32, total: u32) Error!void {
        if (total == 0 or size == 0 or start > total or size > total - start)
            return error.InvalidRarPpmd;
        self.range /= total;
        if (self.range == 0) return error.InvalidRarPpmd;
        self.low +%= start *% self.range;
        self.range *%= size;
        if (self.range == 0) return error.InvalidRarPpmd;
    }

    fn encodeBit0(self: *RangeEncoder, size: u32) Error!void {
        if (size == 0) return error.InvalidRarPpmd;
        self.range = size;
    }

    fn encodeBit1(self: *RangeEncoder, size: u32) Error!void {
        self.low +%= size;
        self.range = (self.range & ~(model_mod.bin_scale - 1)) -% size;
        if (self.range == 0) return error.InvalidRarPpmd;
    }

    fn normalize(self: *RangeEncoder) Error!void {
        while (true) {
            var needed = (self.low ^ (self.low +% self.range)) < top_value;
            if (!needed and self.range < bottom_value) {
                self.range = (0 -% self.low) & (bottom_value - 1);
                needed = true;
            }
            if (!needed) return;
            try self.bytes.append(self.allocator, @truncate(self.low >> 24));
            self.range *%= 256;
            self.low *%= 256;
        }
    }

    fn finishAlloc(self: *RangeEncoder) Error![]u8 {
        for (0..4) |_| {
            try self.bytes.append(self.allocator, @truncate(self.low >> 24));
            self.low *%= 256;
        }
        return self.bytes.toOwnedSlice(self.allocator);
    }
};

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

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: EncodeOptions,
    model: ?model_mod.Model = null,
    initialized: bool = false,
    poisoned: bool = false,

    pub fn init(allocator: std.mem.Allocator, options: EncodeOptions) Encoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Encoder) void {
        if (self.model) |*model| model.deinit();
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        if (self.model) |*model| model.deinit();
        self.model = null;
        self.initialized = false;
        self.poisoned = false;
    }

    pub fn canContinue(self: *const Encoder) bool {
        return self.initialized and !self.poisoned;
    }

    pub fn encodeMemberAlloc(
        self: *Encoder,
        input: []const u8,
        solid: bool,
    ) Error![]u8 {
        const order_bits = try validateEncodeOptions(self.options);
        if (!solid)
            self.reset()
        else {
            if (self.poisoned) return error.RarPpmdEncoderPoisoned;
            if (!self.initialized or self.model == null)
                return error.MissingRarPpmdSolidEncoderState;
        }
        errdefer self.poisoned = true;

        var output: std.ArrayList(u8) = .empty;
        errdefer output.deinit(self.allocator);
        var first_byte: u8 = 0x80 | order_bits;
        if (!solid) first_byte |= 0x20;
        if (self.options.escape != 2) first_byte |= 0x40;
        try output.append(self.allocator, first_byte);
        if (!solid) {
            try output.append(
                self.allocator,
                @intCast(self.options.memory_size / (1024 * 1024) - 1),
            );
            self.model = try model_mod.Model.init(
                self.allocator,
                self.options.order,
                @intCast(self.options.memory_size),
            );
        }
        if (self.options.escape != 2)
            try output.append(self.allocator, self.options.escape);

        var range = RangeEncoder{ .allocator = self.allocator };
        defer range.deinit();
        for (input) |symbol| try self.encodeLiteral(&range, symbol);
        try self.encodeSymbol(&range, self.options.escape);
        try self.encodeSymbol(&range, 2);
        const payload = try range.finishAlloc();
        defer self.allocator.free(payload);
        try output.appendSlice(self.allocator, payload);
        const owned = try output.toOwnedSlice(self.allocator);
        self.initialized = true;
        self.poisoned = false;
        return owned;
    }

    fn encodeLiteral(self: *Encoder, range: *RangeEncoder, symbol: u8) Error!void {
        try self.encodeSymbol(range, symbol);
        if (symbol == self.options.escape) try self.encodeSymbol(range, 1);
    }

    fn encodeSymbol(self: *Encoder, range: *RangeEncoder, symbol: u8) Error!void {
        const model = if (self.model) |*value| value else return error.InvalidRarPpmd;
        var symbol_mask: [256]u8 = @splat(std.math.maxInt(u8));
        const min_context = model.context(model.min_context);
        if (min_context.num_stats != 1) {
            const sum_frequency = @as(u32, min_context.union2.summ_freq);
            var state_offset = min_context.union4.stats;
            var start: u32 = 0;
            for (0..min_context.num_stats) |index| {
                const state = model.state(state_offset).*;
                if (state.symbol == symbol) {
                    try range.encode(start, state.freq, sum_frequency);
                    model.found_state = state_offset;
                    if (index == 0) {
                        model.update1_0();
                    } else {
                        model.prev_success = 0;
                        model.update1();
                    }
                    try range.normalize();
                    return;
                }
                start += state.freq;
                state_offset.value += @sizeOf(model_mod.State);
            }
            if (start >= sum_frequency) return error.InvalidRarPpmd;
            model.prev_success = 0;
            try range.encode(start, sum_frequency - start, sum_frequency);
            model.hi_bits_flag = model_mod.Model.hiBitsFlag3(model.state(model.found_state).symbol);
            state_offset = min_context.union4.stats;
            for (0..min_context.num_stats) |_| {
                symbol_mask[model.state(state_offset).symbol] = 0;
                state_offset.value += @sizeOf(model_mod.State);
            }
        } else {
            const state_offset = model_mod.Offset.init(
                @as(usize, model.min_context.value) + @offsetOf(model_mod.Context, "union2"),
            );
            const state = model.state(state_offset).*;
            const probability = model.getBinSumm();
            var value = @as(u32, probability.*);
            const size0 = (range.range >> 14) * value;
            value -= (value + (1 << (model_mod.period_bits - 2))) >> model_mod.period_bits;
            if (state.symbol == symbol) {
                probability.* = @intCast(value + (1 << model_mod.int_bits));
                try range.encodeBit0(size0);
                model.updateBin(state_offset);
                try range.normalize();
                return;
            }
            probability.* = @intCast(value);
            model.init_esc = model_mod.expEscape(value >> 10);
            try range.encodeBit1(size0);
            symbol_mask[state.symbol] = 0;
            model.prev_success = 0;
        }

        while (true) {
            try range.normalize();
            var context_offset = model.min_context;
            const masked_count = @as(u32, model.context(context_offset).num_stats);
            while (model.context(context_offset).num_stats == masked_count) {
                model.order_fall += 1;
                const suffix = model.context(context_offset).suffix;
                if (suffix.isNull()) return error.InvalidRarPpmd;
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
            var start: u32 = 0;
            state_offset = context.union4.stats;
            for (0..context.num_stats) |_| {
                const state = model.state(state_offset).*;
                const frequency = @as(u32, state.freq & symbol_mask[state.symbol]);
                if (state.symbol == symbol and frequency != 0) {
                    try range.encode(start, frequency, frequency_sum);
                    model.getSee(see_source).update();
                    model.found_state = state_offset;
                    model.update2();
                    try range.normalize();
                    return;
                }
                start += frequency;
                state_offset.value += @sizeOf(model_mod.State);
            }
            try range.encode(high_count, frequency_sum - high_count, frequency_sum);
            model.getSee(see_source).summ +%= @truncate(frequency_sum);
            state_offset = context.union4.stats;
            for (0..context.num_stats) |_| {
                symbol_mask[model.state(state_offset).symbol] = 0;
                state_offset.value += @sizeOf(model_mod.State);
            }
        }
    }
};

pub fn encodeAlloc(
    allocator: std.mem.Allocator,
    input: []const u8,
    options: EncodeOptions,
) Error![]u8 {
    var encoder = Encoder.init(allocator, options);
    defer encoder.deinit();
    return encoder.encodeMemberAlloc(input, false);
}

pub fn validateEncodeOptions(options: EncodeOptions) Error!u8 {
    const order_bits: u8 = if (options.order <= 16)
        options.order -| 1
    else if (options.order <= model_mod.max_order and (options.order - 16) % 3 == 0)
        15 + (options.order - 16) / 3
    else
        return error.InvalidRarPpmdEncodeOptions;
    if (options.order < model_mod.min_order) return error.InvalidRarPpmdEncodeOptions;
    const mib = 1024 * 1024;
    if (options.memory_size < mib or options.memory_size > 256 * mib or
        options.memory_size % mib != 0)
        return error.InvalidRarPpmdEncodeOptions;
    return order_bits;
}

fn readByte(input: []const u8, position: *usize) Error!u8 {
    if (position.* == input.len) return error.TruncatedFrame;
    const byte = input[position.*];
    position.* += 1;
    return byte;
}

fn expectEncodedMember(
    session: *Session,
    encoded: []const u8,
    expected: []const u8,
) !void {
    if (encoded.len == 0) return error.InvalidRarPpmd;
    try session.startBlock(encoded[0], encoded, 1, default_test_memory_limit);
    for (expected) |wanted| {
        const symbol = (try session.decodeSymbol(encoded)) orelse return error.InvalidRarPpmd;
        if (symbol == session.escape) {
            const control = (try session.decodeSymbol(encoded)) orelse return error.InvalidRarPpmd;
            if (control != 1 or wanted != session.escape) return error.InvalidRarPpmd;
        } else if (symbol != wanted) {
            return error.InvalidRarPpmd;
        }
    }
    const escape = (try session.decodeSymbol(encoded)) orelse return error.InvalidRarPpmd;
    const control = (try session.decodeSymbol(encoded)) orelse return error.InvalidRarPpmd;
    if (escape != session.escape or control != 2) return error.InvalidRarPpmd;
}

const default_test_memory_limit = 32 * 1024 * 1024;

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

test "RAR PPMd-H encoder round trips literals escapes and solid model state" {
    const allocator = std.testing.allocator;
    var all_bytes: [256]u8 = undefined;
    for (&all_bytes, 0..) |*byte, index| byte.* = @intCast(index);
    const inputs = [_][]const u8{
        "",
        "PPMd Variant H literal stream\n" ** 32,
        &all_bytes,
    };
    for (inputs) |input| {
        const encoded = try encodeAlloc(allocator, input, .{});
        defer allocator.free(encoded);
        var decoder = Session.init(allocator);
        defer decoder.deinit();
        try expectEncodedMember(&decoder, encoded, input);
    }

    const custom = try encodeAlloc(allocator, &all_bytes, .{
        .order = 19,
        .memory_size = 1024 * 1024,
        .escape = 0xff,
    });
    defer allocator.free(custom);
    var custom_decoder = Session.init(allocator);
    defer custom_decoder.deinit();
    try expectEncodedMember(&custom_decoder, custom, &all_bytes);

    var truncated_decoder = Session.init(allocator);
    defer truncated_decoder.deinit();
    try std.testing.expectError(
        error.TruncatedFrame,
        expectEncodedMember(&truncated_decoder, custom[0 .. custom.len - 1], &all_bytes),
    );

    const first = "solid PPMd shared context alpha beta gamma\n" ** 64;
    const second = "solid PPMd shared context alpha beta delta\n" ** 32;
    var encoder = Encoder.init(allocator, .{});
    defer encoder.deinit();
    const first_packed = try encoder.encodeMemberAlloc(first, false);
    defer allocator.free(first_packed);
    const second_packed = try encoder.encodeMemberAlloc(second, true);
    defer allocator.free(second_packed);
    try std.testing.expect(first_packed[0] & 0x20 != 0);
    try std.testing.expect(second_packed[0] & 0x20 == 0);

    var decoder = Session.init(allocator);
    defer decoder.deinit();
    try expectEncodedMember(&decoder, first_packed, first);
    try expectEncodedMember(&decoder, second_packed, second);
}

test "RAR PPMd-H encoder validates order memory and solid state" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(
        error.InvalidRarPpmdEncodeOptions,
        encodeAlloc(allocator, "payload", .{ .order = 17 }),
    );
    try std.testing.expectError(
        error.InvalidRarPpmdEncodeOptions,
        encodeAlloc(allocator, "payload", .{ .memory_size = 512 * 1024 }),
    );
    var encoder = Encoder.init(allocator, .{});
    defer encoder.deinit();
    try std.testing.expectError(
        error.MissingRarPpmdSolidEncoderState,
        encoder.encodeMemberAlloc("payload", true),
    );
}
