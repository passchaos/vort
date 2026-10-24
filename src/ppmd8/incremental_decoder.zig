const std = @import("std");
const core = @import("../core.zig");
const decoder = @import("decoder.zig");
const model_mod = @import("model.zig");

/// Symbol-progressive PPMd8 decoder. One symbol is transactional: when range
/// normalization needs another byte, the small range state and model metadata
/// are restored while the large context arena remains untouched until a
/// symbol commits.
pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    order: u8,
    memory_size: u32,
    restore_method: model_mod.RestoreMethod,
    model: model_mod.Model,
    range: ?decoder.RangeDecoder = null,
    compressed: std.ArrayList(u8) = .empty,
    phase: Phase = .range_prefix,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .range_prefix,

    const Self = @This();

    pub const Error = decoder.Error || error{OutputLimitExceeded};
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        max_compressed_buffer_len: usize = 1024 * 1024,
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum { range_prefix, symbols, done, failed };
    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        buffered_compressed_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
        restore_method: model_mod.RestoreMethod,
        options: Options,
    ) Error!Self {
        return .{
            .allocator = allocator,
            .options = options,
            .order = order,
            .memory_size = memory_size,
            .restore_method = restore_method,
            .model = try model_mod.Model.init(allocator, order, memory_size, restore_method),
        };
    }

    pub fn deinit(self: *Self) void {
        self.model.deinit();
        self.compressed.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Self) Error!void {
        const replacement_model = try model_mod.Model.init(
            self.allocator,
            self.order,
            self.memory_size,
            self.restore_method,
        );
        self.model.deinit();
        self.model = replacement_model;
        self.range = null;
        self.compressed.clearRetainingCapacity();
        self.phase = .range_prefix;
        self.input_finished = false;
        self.total_input = 0;
        self.total_output = 0;
        self.last_error_name = "";
        self.last_error_phase = .range_prefix;
    }

    pub fn finish(self: *Self) void {
        self.input_finished = true;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_compressed_bytes = self.compressed.items.len,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
            .payload_remaining = null,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (self.phase == .failed) "payload_corrupt" else "none",
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.InvalidPpmdData;
        if (self.phase == .done) return .{ .status = .done };
        return self.stepInner(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            self.phase = .failed;
            return err;
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var input_read: usize = 0;
        var output_written: usize = 0;
        if (self.phase == .range_prefix) {
            while (self.compressed.items.len < 4 and input_read < input.len)
                try self.appendInputByte(input, &input_read);
            if (self.compressed.items.len < 4) {
                if (self.input_finished) return error.TruncatedPpmdInput;
                return result(input_read, output_written, .need_input);
            }
            self.range = try decoder.RangeDecoder.init(self.compressed.items);
            self.phase = .symbols;
        }

        while (true) {
            if (output_written == output.len)
                return result(input_read, output_written, .need_output);
            const model_checkpoint = self.model;
            const range_checkpoint = self.range.?;
            const symbol = decoder.decodeSymbol(&self.model, &self.range.?) catch |err| switch (err) {
                error.TruncatedPpmdInput => {
                    self.model = model_checkpoint;
                    self.range = range_checkpoint;
                    if (input_read == input.len) {
                        if (self.input_finished) return error.TruncatedPpmdInput;
                        return result(input_read, output_written, .need_input);
                    }
                    try self.appendInputByte(input, &input_read);
                    continue;
                },
                else => |decode_error| return decode_error,
            };
            if (symbol) |byte| {
                if (self.total_output >= self.options.max_output_len)
                    return error.OutputLimitExceeded;
                if (self.options.expected_output_len) |expected|
                    if (self.total_output >= expected) return error.SizeMismatch;
                output[output_written] = byte;
                output_written += 1;
                self.total_output += 1;
                self.compactConsumedInput();
                continue;
            }
            if (self.range.?.codeValue() != 0) return error.InvalidPpmdData;
            if (self.options.expected_output_len) |expected|
                if (self.total_output != expected) return error.SizeMismatch;
            self.compactConsumedInput();
            self.phase = .done;
            return result(input_read, output_written, .done);
        }
    }

    fn appendInputByte(self: *Self, input: []const u8, input_read: *usize) Error!void {
        self.compactConsumedInput();
        if (self.compressed.items.len == self.options.max_compressed_buffer_len)
            return error.OutputLimitExceeded;
        try self.compressed.append(self.allocator, input[input_read.*]);
        input_read.* += 1;
        self.total_input += 1;
        if (self.range) |*range| try range.setInput(self.compressed.items);
    }

    fn compactConsumedInput(self: *Self) void {
        const range = &(self.range orelse return);
        const consumed = range.consumed();
        if (consumed == 0) return;
        const remaining = self.compressed.items.len - consumed;
        std.mem.copyForwards(u8, self.compressed.items[0..remaining], self.compressed.items[consumed..]);
        self.compressed.shrinkRetainingCapacity(remaining);
        range.replaceConsumedInput(self.compressed.items);
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};
