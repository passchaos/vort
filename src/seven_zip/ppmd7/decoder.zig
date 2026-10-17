const std = @import("std");
const core = @import("../../core.zig");
const model_mod = @import("model.zig");

pub const Error = model_mod.Error || core.Error || error{
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

pub const IncrementalDecoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    model: model_mod.Model,
    compressed: std.ArrayList(u8) = .empty,
    range_decoder: ?RangeDecoder = null,
    decoded: usize = 0,
    output_written: usize = 0,
    input_finished: bool = false,
    phase: Phase = .range_prefix,
    last_error_name: []const u8 = "",

    const symbol_input_guard: usize = 512;

    pub const Options = struct {
        order: u8,
        memory_size: u32,
        expected_output_len: usize,
        max_output_len: usize = std.math.maxInt(usize),
        max_memory_size: usize = std.math.maxInt(usize),
        max_compressed_buffer_len: usize = 1024 * 1024,
    };

    pub const Phase = enum {
        range_prefix,
        symbols,
        validate,
        done,
    };

    pub const Snapshot = struct {
        phase: Phase,
        decoded: usize,
        output_written: usize,
        buffered_compressed_bytes: usize,
        retained_compressed_capacity: usize,
        model_memory_size: u32,
        input_finished: bool,
        last_error_name: []const u8,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!IncrementalDecoder {
        if (options.expected_output_len > options.max_output_len or
            options.memory_size > options.max_memory_size or
            options.max_compressed_buffer_len < 5)
            return error.OutputLimitExceeded;
        return .{
            .allocator = allocator,
            .options = options,
            .model = try model_mod.Model.init(allocator, options.order, options.memory_size),
        };
    }

    pub fn deinit(self: *IncrementalDecoder) void {
        self.model.deinit();
        self.compressed.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn finish(self: *IncrementalDecoder) void {
        self.input_finished = true;
    }

    pub fn snapshot(self: *const IncrementalDecoder) Snapshot {
        return .{
            .phase = self.phase,
            .decoded = self.decoded,
            .output_written = self.output_written,
            .buffered_compressed_bytes = self.bufferedLen(),
            .retained_compressed_capacity = self.compressed.capacity,
            .model_memory_size = self.options.memory_size,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
        };
    }

    pub fn step(
        self: *IncrementalDecoder,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        return self.stepInternal(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            return err;
        };
    }

    fn stepInternal(
        self: *IncrementalDecoder,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.PpmdTrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.PpmdTrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .range_prefix => {
                if (!try self.ensureBuffered(5, input, &input_read)) {
                    if (self.input_finished) return error.TruncatedPpmdInput;
                    return streamResult(input_read, output_written, .need_input);
                }
                self.range_decoder = try RangeDecoder.init(self.compressed.items);
                self.phase = .symbols;
            },
            .symbols => {
                if (self.decoded == self.options.expected_output_len) {
                    self.phase = .validate;
                    continue;
                }
                if (output_written == output.len)
                    return streamResult(input_read, output_written, .need_output);
                if (!self.input_finished and self.bufferedLen() < symbol_input_guard) {
                    if (!try self.ensureBuffered(symbol_input_guard, input, &input_read))
                        return streamResult(input_read, output_written, .need_input);
                }
                self.range_decoder.?.input = self.compressed.items;
                output[output_written] = try decodeSymbol(&self.model, &self.range_decoder.?);
                output_written += 1;
                self.output_written += 1;
                self.decoded += 1;
            },
            .validate => {
                if (input_read != input.len) {
                    try self.appendInput(input[input_read..]);
                    input_read = input.len;
                    self.range_decoder.?.input = self.compressed.items;
                }
                if (!self.input_finished)
                    return streamResult(input_read, output_written, .need_input);
                if (self.range_decoder.?.code != 0) return error.InvalidPpmdData;
                if (self.range_decoder.?.position != self.compressed.items.len)
                    return error.PpmdTrailingData;
                self.phase = .done;
                return streamResult(input_read, output_written, .done);
            },
            .done => unreachable,
        };
    }

    fn ensureBuffered(
        self: *IncrementalDecoder,
        needed: usize,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        if (self.bufferedLen() >= needed) return true;
        try self.compact();
        const target = @min(needed, self.options.max_compressed_buffer_len);
        if (target <= self.compressed.items.len) return error.OutputLimitExceeded;
        const take = @min(target - self.compressed.items.len, input.len - input_read.*);
        if (take != 0) {
            try self.compressed.appendSlice(
                self.allocator,
                input[input_read.*..][0..take],
            );
            input_read.* += take;
            if (self.range_decoder) |*decoder| decoder.input = self.compressed.items;
        }
        return self.bufferedLen() >= needed;
    }

    fn appendInput(self: *IncrementalDecoder, input: []const u8) Error!void {
        try self.compact();
        const next = std.math.add(usize, self.compressed.items.len, input.len) catch
            return error.OutputLimitExceeded;
        if (next > self.options.max_compressed_buffer_len)
            return error.OutputLimitExceeded;
        try self.compressed.appendSlice(self.allocator, input);
        if (self.range_decoder) |*decoder| decoder.input = self.compressed.items;
    }

    fn compact(self: *IncrementalDecoder) Error!void {
        const position = if (self.range_decoder) |decoder| decoder.position else 0;
        if (position == 0) return;
        if (position > self.compressed.items.len) return error.InvalidPpmdData;
        const remaining = self.compressed.items.len - position;
        std.mem.copyForwards(
            u8,
            self.compressed.items[0..remaining],
            self.compressed.items[position..],
        );
        self.compressed.items.len = remaining;
        self.range_decoder.?.position = 0;
        self.range_decoder.?.input = self.compressed.items;
    }

    fn bufferedLen(self: *const IncrementalDecoder) usize {
        const position = if (self.range_decoder) |decoder| decoder.position else 0;
        return self.compressed.items.len - position;
    }
};

fn streamResult(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{ .input_read = input_read, .output_written = output_written },
        .status = status,
    };
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

test "PPMd7 incremental decoder handles byte input and tiny output" {
    const encoded = [_]u8{
        0x00, 0x73, 0x02, 0x14, 0x49, 0xc6, 0x00, 0x2c,
        0x4c, 0x7f, 0xcc, 0x8f, 0xf0, 0xb0, 0x74, 0x5b,
        0x24, 0x9d, 0xa3, 0x94, 0x7b, 0xcf, 0x29, 0xdb,
        0xf7, 0xa3, 0xf8, 0x00,
    };
    const expected = "src/br/dictionary.bin binary\n";
    var decoder = try IncrementalDecoder.init(std.testing.allocator, .{
        .order = 6,
        .memory_size = 64 * 1024,
        .expected_output_len = expected.len,
        .max_output_len = expected.len,
    });
    defer decoder.deinit();
    var output: [expected.len]u8 = undefined;
    var input_offset: usize = 0;
    var output_offset: usize = 0;
    while (true) {
        const input_end = @min(encoded.len, input_offset + 1);
        if (input_offset == encoded.len) decoder.finish();
        const output_end = @min(output.len, output_offset + 1);
        const stepped = try decoder.step(
            encoded[input_offset..input_end],
            output[output_offset..output_end],
        );
        input_offset += stepped.progress.input_read;
        output_offset += stepped.progress.output_written;
        if (stepped.status == .done) break;
    }
    try std.testing.expectEqual(encoded.len, input_offset);
    try std.testing.expectEqual(expected.len, output_offset);
    try std.testing.expectEqualSlices(u8, expected, &output);
}

test "PPMd7 incremental decoder enforces limits truncation and OOM" {
    const encoded = [_]u8{
        0x00, 0x73, 0x02, 0x14, 0x49, 0xc6, 0x00, 0x2c,
        0x4c, 0x7f, 0xcc, 0x8f, 0xf0, 0xb0, 0x74, 0x5b,
        0x24, 0x9d, 0xa3, 0x94, 0x7b, 0xcf, 0x29, 0xdb,
        0xf7, 0xa3, 0xf8, 0x00,
    };
    const expected = "src/br/dictionary.bin binary\n";
    try std.testing.expectError(
        error.OutputLimitExceeded,
        IncrementalDecoder.init(std.testing.allocator, .{
            .order = 6,
            .memory_size = 64 * 1024,
            .expected_output_len = expected.len,
            .max_memory_size = 32 * 1024,
        }),
    );

    var truncated = try IncrementalDecoder.init(std.testing.allocator, .{
        .order = 6,
        .memory_size = 64 * 1024,
        .expected_output_len = expected.len,
    });
    defer truncated.deinit();
    _ = try truncated.step(encoded[0 .. encoded.len - 1], &.{});
    truncated.finish();
    var scratch: [expected.len]u8 = undefined;
    if (truncated.step("", &scratch)) |_| {
        return error.TestUnexpectedResult;
    } else |err| {
        try std.testing.expect(err == error.TruncatedPpmdInput or err == error.InvalidPpmdData);
    }

    const FailureTest = struct {
        fn run(allocator: std.mem.Allocator, payload: []const u8, plain: []const u8) !void {
            var state = try IncrementalDecoder.init(allocator, .{
                .order = 6,
                .memory_size = 64 * 1024,
                .expected_output_len = plain.len,
                .max_output_len = plain.len,
            });
            defer state.deinit();
            const output = try allocator.alloc(u8, plain.len);
            defer allocator.free(output);
            var input_offset: usize = 0;
            var output_offset: usize = 0;
            while (true) {
                const input_end = @min(payload.len, input_offset + 3);
                if (input_offset == payload.len) state.finish();
                const output_end = @min(output.len, output_offset + 2);
                const stepped = try state.step(
                    payload[input_offset..input_end],
                    output[output_offset..output_end],
                );
                input_offset += stepped.progress.input_read;
                output_offset += stepped.progress.output_written;
                if (stepped.status == .done) break;
            }
            try std.testing.expectEqualSlices(u8, plain, output);
        }
    };
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        FailureTest.run,
        .{ &encoded, expected },
    );
}
