const std = @import("std");
const core = @import("../../core.zig");

pub const Error = std.mem.Allocator.Error || error{
    OutputLimitExceeded,
    SizeMismatch,
    TrailingData,
    IntegerOverflow,
};

const control_code: u16 = 256;
const first_free_code: u16 = 257;
const min_bits: u4 = 9;
const max_bits: u4 = 13;
const dictionary_size: usize = 1 << max_bits;

/// Caller-output ZIP Shrink encoder. LZW prefix, 9...13-bit width, dictionary,
/// and LSB-first reservoir survive arbitrary input/output fragmentation.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    dictionary: std.AutoHashMap(u32, u16),
    bits: u4 = min_bits,
    next_code: u16 = first_free_code,
    prefix: ?u16 = null,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    finishing: bool = false,
    final_written: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,

    const Self = @This();

    pub const Options = struct {
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        pending_output: usize,
        code_bits: u4,
        next_code: u16,
        dictionary_entries: usize,
        finishing: bool,
        done: bool,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Self {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
        if (options.max_pending_output_len == 0) return error.OutputLimitExceeded;
        var dictionary = std.AutoHashMap(u32, u16).init(allocator);
        errdefer dictionary.deinit();
        try dictionary.ensureTotalCapacity(dictionary_size - first_free_code);
        return .{
            .allocator = allocator,
            .options = options,
            .dictionary = dictionary,
        };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Self {
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        var state = try initWithOptions(allocator, options);
        state.expected_input_len = expected_input_len;
        return state;
    }

    pub fn deinit(self: *Self) void {
        self.dictionary.deinit();
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Self) void {
        self.dictionary.clearRetainingCapacity();
        self.bits = min_bits;
        self.next_code = first_free_code;
        self.prefix = null;
        self.reservoir = 0;
        self.bit_count = 0;
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.finishing = false;
        self.final_written = false;
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
            .code_bits = self.bits,
            .next_code = self.next_code,
            .dictionary_entries = self.dictionary.count(),
            .finishing = self.finishing,
            .done = self.done,
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
                const byte = input[input_read];
                if (self.prefix) |prefix| {
                    const key = (@as(u32, prefix) << 8) | byte;
                    if (self.dictionary.get(key)) |code| {
                        self.prefix = code;
                    } else {
                        try self.writeCode(prefix, self.bits);
                        if (self.next_code < dictionary_size) {
                            if (self.next_code == @as(u16, 1) << self.bits) {
                                try self.writeCode(control_code, self.bits);
                                try self.writeCode(1, self.bits);
                                self.bits += 1;
                            }
                            try self.dictionary.put(key, self.next_code);
                            self.next_code += 1;
                        }
                        self.prefix = byte;
                    }
                } else {
                    self.prefix = byte;
                }
                try self.checkPendingLimit();
                input_read += 1;
                self.total_input = std.math.add(usize, self.total_input, 1) catch
                    return error.IntegerOverflow;
                continue;
            }

            if (self.finishing and !self.final_written) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                if (self.prefix) |prefix| try self.writeCode(prefix, self.bits);
                if (self.bit_count != 0) {
                    try self.pending.append(self.allocator, @truncate(self.reservoir));
                    self.reservoir = 0;
                    self.bit_count = 0;
                }
                try self.checkPendingLimit();
                self.final_written = true;
                continue;
            }
            if (self.finishing) {
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn writeCode(self: *Self, value: u16, count: u4) Error!void {
        self.reservoir |= @as(u64, value) << @intCast(self.bit_count);
        self.bit_count += count;
        while (self.bit_count >= 8) {
            try self.pending.append(self.allocator, @truncate(self.reservoir));
            self.reservoir >>= 8;
            self.bit_count -= 8;
        }
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
