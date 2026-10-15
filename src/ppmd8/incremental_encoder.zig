const std = @import("std");
const core = @import("../core.zig");
const encoder = @import("encoder.zig");
const model_mod = @import("model.zig");

/// Symbol-progressive PPMd8 encoder. The model arena is fixed by initialization
/// and input symbols commit directly into range state; no plaintext member is
/// retained. Encoded bytes drain through arbitrary caller output slices.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    order: u8,
    memory_size: u32,
    restore_method: model_mod.RestoreMethod,
    model: model_mod.Model,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    range: u32 = std.math.maxInt(u32),
    low: u32 = 0,
    finishing: bool = false,
    end_encoded: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,

    const Self = @This();

    pub const Error = encoder.Error || error{
        OutputLimitExceeded,
        SizeMismatch,
        TrailingData,
        IntegerOverflow,
    };
    pub const Options = struct {
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        pending_output: usize,
        finishing: bool,
        done: bool,
        model_memory_size: u32,
    };

    pub fn init(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
        restore_method: model_mod.RestoreMethod,
    ) Error!Self {
        return initWithOptions(
            allocator,
            order,
            memory_size,
            restore_method,
            .{},
        );
    }

    pub fn initWithOptions(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
        restore_method: model_mod.RestoreMethod,
        options: Options,
    ) Error!Self {
        if (options.max_pending_output_len == 0) return error.OutputLimitExceeded;
        return .{
            .allocator = allocator,
            .options = options,
            .order = order,
            .memory_size = memory_size,
            .restore_method = restore_method,
            .model = try model_mod.Model.init(
                allocator,
                order,
                memory_size,
                restore_method,
            ),
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        order: u8,
        memory_size: u32,
        restore_method: model_mod.RestoreMethod,
        options: Options,
        expected_input_len: usize,
    ) Error!Self {
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        var state = try initWithOptions(
            allocator,
            order,
            memory_size,
            restore_method,
            options,
        );
        state.expected_input_len = expected_input_len;
        return state;
    }

    pub fn deinit(self: *Self) void {
        self.model.deinit();
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Self) Error!void {
        const replacement = try model_mod.Model.init(
            self.allocator,
            self.order,
            self.memory_size,
            self.restore_method,
        );
        self.model.deinit();
        self.model = replacement;
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.range = std.math.maxInt(u32);
        self.low = 0;
        self.finishing = false;
        self.end_encoded = false;
        self.done = false;
        self.total_input = 0;
        self.total_output = 0;
    }

    pub fn finish(self: *Self) void {
        if (!self.done) self.finishing = true;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .pending_output = self.pending.items.len - self.pending_offset,
            .finishing = self.finishing,
            .done = self.done,
            .model_memory_size = self.memory_size,
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        if (output.len == 0) return .{ .status = .need_output };

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            try self.drainPending(output, &output_written);
            if (self.pending_offset != self.pending.items.len)
                return result(input_read, output_written, .need_output);
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            if (output_written == output.len)
                return result(input_read, output_written, .need_output);

            if (input_read < input.len) {
                if (self.total_input == self.options.max_input_len)
                    return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (self.total_input == expected) return error.SizeMismatch;
                var range_encoder = self.rangeEncoder();
                try encoder.encodeSymbol(
                    &self.model,
                    &range_encoder,
                    input[input_read],
                );
                self.saveRange(range_encoder);
                try self.checkPendingLimit();
                input_read += 1;
                self.total_input = std.math.add(usize, self.total_input, 1) catch
                    return error.IntegerOverflow;
                continue;
            }

            if (self.finishing and !self.end_encoded) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                var range_encoder = self.rangeEncoder();
                try encoder.encodeSymbol(&self.model, &range_encoder, null);
                try range_encoder.finish();
                self.saveRange(range_encoder);
                try self.checkPendingLimit();
                self.end_encoded = true;
                continue;
            }
            if (self.finishing) {
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn rangeEncoder(self: *Self) encoder.RangeEncoder {
        return .{
            .allocator = self.allocator,
            .output = &self.pending,
            .range = self.range,
            .low = self.low,
        };
    }

    fn saveRange(self: *Self, range_encoder: encoder.RangeEncoder) void {
        self.range = range_encoder.range;
        self.low = range_encoder.low;
    }

    fn drainPending(self: *Self, output: []u8, output_written: *usize) Error!void {
        const remaining = self.pending.items[self.pending_offset..];
        const take = @min(output.len - output_written.*, remaining.len);
        @memcpy(output[output_written.*..][0..take], remaining[0..take]);
        self.pending_offset += take;
        output_written.* += take;
        self.total_output = std.math.add(usize, self.total_output, take) catch
            return error.IntegerOverflow;
    }

    fn checkPendingLimit(self: *const Self) Error!void {
        if (self.pending.items.len > self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{
                .input_read = input_read,
                .output_written = output_written,
            },
            .status = status,
        };
    }
};
