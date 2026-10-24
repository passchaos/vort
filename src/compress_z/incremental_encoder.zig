//! Bit-progressive Unix compress (`.Z`) LZW encoder.

const std = @import("std");
const core = @import("../core.zig");
const encoder = @import("encoder.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    dictionary: std.AutoHashMap(u32, u16),
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    code_bits: u5 = initial_code_bits,
    next_code: usize,
    current_code: ?u16 = null,
    bit_buffer: u32 = 0,
    bit_count: u6 = 0,
    payload_bits_written: usize = 0,
    group_base_bits: usize = 0,
    finishing: bool = false,
    final_code_written: bool = false,
    tail_flushed: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,
    code_count: usize = 0,
    clear_count: usize = 0,
    width_growth_count: usize = 0,

    const initial_code_bits: u5 = 9;
    const clear_code: u16 = 256;
    const block_first_code: usize = 257;
    const literal_count: usize = 256;

    pub const Error = encoder.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_code_bits: u5 = 16,
        block_mode: bool = true,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 1024 * 1024,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        pending_output: usize,
        max_code_bits: u5,
        code_bits: u5,
        next_code: usize,
        dictionary_entries: usize,
        current_code: ?u16,
        buffered_bits: u6,
        code_count: usize,
        clear_count: usize,
        width_growth_count: usize,
        finishing: bool,
        done: bool,
        retained_dictionary_capacity: usize,
        retained_output_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        const first_code = if (options.block_mode) block_first_code else literal_count;
        const capacity = (@as(usize, 1) << options.max_code_bits) - first_code;
        var state = Encoder{
            .allocator = allocator,
            .options = options,
            .dictionary = try initDictionary(allocator, capacity),
            .next_code = first_code,
        };
        errdefer state.deinit();
        try state.appendHeader();
        return state;
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        var state = try initWithOptions(allocator, options);
        if (expected_input_len > options.max_input_len) {
            state.deinit();
            return error.OutputLimitExceeded;
        }
        state.expected_input_len = expected_input_len;
        return state;
    }

    pub fn deinit(self: *Encoder) void {
        self.dictionary.deinit();
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        self.dictionary.clearRetainingCapacity();
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.code_bits = initial_code_bits;
        self.next_code = if (self.options.block_mode) block_first_code else literal_count;
        self.current_code = null;
        self.bit_buffer = 0;
        self.bit_count = 0;
        self.payload_bits_written = 0;
        self.group_base_bits = 0;
        self.finishing = false;
        self.final_code_written = false;
        self.tail_flushed = false;
        self.done = false;
        self.total_input = 0;
        self.total_output = 0;
        self.code_count = 0;
        self.clear_count = 0;
        self.width_growth_count = 0;
        self.appendHeader() catch unreachable;
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .pending_output = self.pending.items.len - self.pending_offset,
            .max_code_bits = self.options.max_code_bits,
            .code_bits = self.code_bits,
            .next_code = self.next_code,
            .dictionary_entries = self.dictionary.count(),
            .current_code = self.current_code,
            .buffered_bits = self.bit_count,
            .code_count = self.code_count,
            .clear_count = self.clear_count,
            .width_growth_count = self.width_growth_count,
            .finishing = self.finishing,
            .done = self.done,
            .retained_dictionary_capacity = self.dictionary.capacity(),
            .retained_output_capacity = self.pending.capacity,
        };
    }

    pub fn finish(self: *Encoder) void {
        if (!self.done) self.finishing = true;
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(remaining.len, output.len - output_written);
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.total_output = try checkedAdd(self.total_output, take);
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return result(input_read, output_written, .need_output);
            }

            if (input_read < input.len) {
                const byte = input[input_read];
                if (self.current_code == null) {
                    try self.acceptInputByte();
                    self.current_code = byte;
                    input_read += 1;
                    continue;
                }
                const key = pairKey(self.current_code.?, byte);
                if (self.dictionary.get(key)) |found| {
                    try self.acceptInputByte();
                    self.current_code = found;
                    input_read += 1;
                    continue;
                }

                try self.growCodeWidth();
                try self.writeCode(self.current_code.?);
                if (self.next_code < self.insertionLimit()) {
                    try self.dictionary.put(key, @intCast(self.next_code));
                    self.next_code += 1;
                } else if (self.options.block_mode) {
                    try self.writeCode(clear_code);
                    try self.alignToCodeGroup();
                    self.dictionary.clearRetainingCapacity();
                    self.code_bits = initial_code_bits;
                    self.next_code = block_first_code;
                    self.clear_count = try checkedAdd(self.clear_count, 1);
                }
                try self.acceptInputByte();
                self.current_code = byte;
                input_read += 1;
                try self.checkPendingLimit();
                continue;
            }

            if (self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                if (!self.final_code_written) {
                    if (self.current_code) |code| {
                        try self.growCodeWidth();
                        try self.writeCode(code);
                    }
                    self.current_code = null;
                    self.final_code_written = true;
                    try self.checkPendingLimit();
                    continue;
                }
                if (!self.tail_flushed) {
                    if (self.bit_count != 0) {
                        try self.pending.append(self.allocator, @truncate(self.bit_buffer));
                        self.bit_buffer = 0;
                        self.bit_count = 0;
                    }
                    self.tail_flushed = true;
                    try self.checkPendingLimit();
                    continue;
                }
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn appendHeader(self: *Encoder) Error!void {
        try self.pending.appendSlice(self.allocator, &.{
            0x1f,
            0x9d,
            @as(u8, self.options.max_code_bits) |
                @as(u8, if (self.options.block_mode) 0x80 else 0),
        });
        try self.checkPendingLimit();
    }

    fn acceptInputByte(self: *Encoder) Error!void {
        const next = try checkedAdd(self.total_input, 1);
        if (next > self.options.max_input_len) return error.OutputLimitExceeded;
        if (self.expected_input_len) |expected|
            if (next > expected) return error.SizeMismatch;
        self.total_input = next;
    }

    fn growCodeWidth(self: *Encoder) Error!void {
        if (self.code_bits >= self.options.max_code_bits) return;
        if (self.next_code <= (@as(usize, 1) << self.code_bits)) return;
        try self.alignToCodeGroup();
        self.code_bits += 1;
        self.width_growth_count = try checkedAdd(self.width_growth_count, 1);
    }

    fn writeCode(self: *Encoder, code: u16) Error!void {
        self.bit_buffer |= @as(u32, code) << @intCast(self.bit_count);
        self.bit_count += @intCast(self.code_bits);
        self.payload_bits_written = try checkedAdd(
            self.payload_bits_written,
            self.code_bits,
        );
        self.code_count = try checkedAdd(self.code_count, 1);
        try self.flushWholeBytes();
    }

    fn alignToCodeGroup(self: *Encoder) Error!void {
        const group_bits = @as(usize, self.code_bits) * 8;
        const relative = self.payload_bits_written - self.group_base_bits;
        const rounded = std.math.add(usize, relative, group_bits - 1) catch
            return error.IntegerOverflow;
        const target = self.group_base_bits + rounded / group_bits * group_bits;
        var padding = target - self.payload_bits_written;
        while (padding != 0) {
            const take: u6 = @intCast(@min(padding, 24));
            self.bit_count += take;
            self.payload_bits_written += take;
            padding -= take;
            try self.flushWholeBytes();
        }
        self.group_base_bits = target;
    }

    fn flushWholeBytes(self: *Encoder) Error!void {
        while (self.bit_count >= 8) {
            try self.pending.append(self.allocator, @truncate(self.bit_buffer));
            self.bit_buffer >>= 8;
            self.bit_count -= 8;
        }
    }

    fn insertionLimit(self: *const Encoder) usize {
        const capacity = @as(usize, 1) << self.options.max_code_bits;
        return if (self.options.block_mode and
            self.options.max_code_bits == initial_code_bits)
            capacity - 1
        else
            capacity;
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset >
            self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn validateOptions(options: Options) Error!void {
        if (options.max_code_bits < initial_code_bits or
            options.max_code_bits > 16 or options.max_pending_output_len < 3)
            return error.InvalidCompressHeader;
    }

    fn pairKey(prefix: u16, suffix: u8) u32 {
        return (@as(u32, prefix) << 8) | suffix;
    }

    fn initDictionary(
        allocator: std.mem.Allocator,
        capacity: usize,
    ) Error!std.AutoHashMap(u32, u16) {
        var dictionary = std.AutoHashMap(u32, u16).init(allocator);
        errdefer dictionary.deinit();
        try dictionary.ensureTotalCapacity(@intCast(capacity));
        return dictionary;
    }

    fn checkedAdd(a: usize, b: usize) Error!usize {
        return std.math.add(usize, a, b) catch error.IntegerOverflow;
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
