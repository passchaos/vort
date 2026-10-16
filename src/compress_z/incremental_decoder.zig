//! Bit-progressive Unix compress (`.Z`) LZW decoder.

const std = @import("std");
const core = @import("../core.zig");
const decoder = @import("decoder.zig");

pub const Decoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    phase: Phase = .header,
    header_bytes: [3]u8 = undefined,
    header_len: usize = 0,
    header: ?decoder.Header = null,
    prefixes: []u16 = &.{},
    suffixes: []u8 = &.{},
    reversed: []u8 = &.{},
    reversed_len: usize = 0,
    reversed_index: usize = 0,
    code_bits: u5 = initial_code_bits,
    max_code: usize = 0,
    next_code: usize = 0,
    previous_code: ?u16 = null,
    first_byte: u8 = 0,
    bit_buffer: u32 = 0,
    bit_count: u6 = 0,
    payload_bits_read: usize = 0,
    group_base_bits: usize = 0,
    alignment_remaining: usize = 0,
    alignment_action: AlignmentAction = .none,
    require_code: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    code_count: usize = 0,
    clear_count: usize = 0,
    width_growth_count: usize = 0,
    input_finished: bool = false,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header,

    const initial_code_bits: u5 = 9;
    const clear_code: u16 = 256;
    const block_first_code: usize = 257;
    const literal_count: usize = 256;
    const AlignmentAction = enum { none, grow, clear };

    pub const Error = decoder.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };
    pub const Phase = enum { header, code, alignment, output, done };
    pub const Snapshot = struct {
        phase: Phase,
        header_received: usize,
        input_read: usize,
        output_written: usize,
        pending_output: usize,
        max_code_bits: ?u5,
        code_bits: u5,
        next_code: usize,
        code_count: usize,
        clear_count: usize,
        width_growth_count: usize,
        buffered_bits: u6,
        alignment_bits_remaining: usize,
        dictionary_capacity: usize,
        retained_dictionary_bytes: usize,
        retained_string_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(allocator: std.mem.Allocator) Decoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Decoder {
        return .{ .allocator = allocator, .options = options };
    }

    pub fn deinit(self: *Decoder) void {
        self.freeDictionary();
        self.* = undefined;
    }

    pub fn reset(self: *Decoder) void {
        self.resetWithOptions(self.options);
    }

    pub fn resetWithOptions(self: *Decoder, options: Options) void {
        const allocator = self.allocator;
        self.freeDictionary();
        self.* = .{ .allocator = allocator, .options = options };
    }

    pub fn snapshot(self: *const Decoder) Snapshot {
        return .{
            .phase = self.phase,
            .header_received = self.header_len,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .pending_output = self.reversed_index,
            .max_code_bits = if (self.header) |header| header.max_code_bits else null,
            .code_bits = self.code_bits,
            .next_code = self.next_code,
            .code_count = self.code_count,
            .clear_count = self.clear_count,
            .width_growth_count = self.width_growth_count,
            .buffered_bits = self.bit_count,
            .alignment_bits_remaining = self.alignment_remaining,
            .dictionary_capacity = self.prefixes.len,
            .retained_dictionary_bytes = self.prefixes.len * @sizeOf(u16) + self.suffixes.len,
            .retained_string_bytes = self.reversed.len,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Decoder) core.StreamingDiagnostics {
        const snap = self.snapshot();
        return .{
            .phase_name = @tagName(snap.phase),
            .header_received = snap.header_received,
            .frame_input_read = snap.input_read,
            .output_written = snap.output_written,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = snap.pending_output,
            .last_error_name = snap.last_error_name,
            .last_error_phase_name = if (snap.last_error_name.len == 0)
                ""
            else
                @tagName(snap.last_error_phase),
        };
    }

    /// `.Z` has no end marker. Call this at physical EOF; fewer than eight
    /// unused tail bits are accepted, while one or more incomplete bytes fail.
    pub fn finish(self: *Decoder) void {
        self.input_finished = true;
    }

    pub fn step(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        return self.stepInner(input, output) catch |err| {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            return err;
        };
    }

    fn stepInner(self: *Decoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.TrailingData;
        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header => {
                const take = @min(self.header_bytes.len - self.header_len, input.len - input_read);
                @memcpy(
                    self.header_bytes[self.header_len..][0..take],
                    input[input_read..][0..take],
                );
                self.header_len += take;
                input_read += take;
                try self.recordInput(take);
                if (self.header_len != self.header_bytes.len) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.acceptHeader();
                self.phase = .code;
            },
            .code => {
                if (!try self.ensureBits(self.code_bits, input, &input_read)) {
                    if (!self.input_finished)
                        return result(input_read, output_written, .need_input);
                    if (self.require_code or self.bit_count >= 8)
                        return error.TruncatedFrame;
                    try self.complete();
                    return result(input_read, output_written, .done);
                }

                const header = self.header.?;
                if (self.code_bits < header.max_code_bits and self.next_code > self.max_code) {
                    try self.beginAlignment(.grow);
                    self.require_code = true;
                    self.phase = .alignment;
                    continue;
                }
                self.require_code = false;
                const encoded_code = try self.readCode(self.code_bits);
                self.code_count = try checkedAdd(self.code_count, 1);
                if (header.block_mode and encoded_code == clear_code) {
                    if (self.previous_code == null) return error.InvalidCompressStream;
                    try self.beginAlignment(.clear);
                    self.phase = .alignment;
                    continue;
                }
                try self.prepareString(encoded_code);
                self.phase = .output;
            },
            .alignment => {
                if (!try self.skipAlignment(input, &input_read)) {
                    if (self.input_finished) return error.TruncatedFrame;
                    return result(input_read, output_written, .need_input);
                }
                try self.applyAlignment();
                self.phase = .code;
            },
            .output => {
                const output_start = output_written;
                while (self.reversed_index != 0 and output_written != output.len) {
                    self.reversed_index -= 1;
                    output[output_written] = self.reversed[self.reversed_index];
                    output_written += 1;
                }
                self.total_output = try checkedAdd(
                    self.total_output,
                    output_written - output_start,
                );
                if (self.total_output > self.options.max_output_len)
                    return error.OutputLimitExceeded;
                if (self.options.expected_output_len) |expected|
                    if (self.total_output > expected) return error.SizeMismatch;
                if (self.reversed_index != 0)
                    return result(input_read, output_written, .need_output);
                self.reversed_len = 0;
                self.phase = .code;
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
            },
            .done => return result(input_read, output_written, .done),
        };
    }

    fn acceptHeader(self: *Decoder) Error!void {
        const parsed = try decoder.parseHeader(&self.header_bytes);
        const capacity = @as(usize, 1) << parsed.max_code_bits;
        const prefixes = try self.allocator.alloc(u16, capacity);
        errdefer self.allocator.free(prefixes);
        const suffixes = try self.allocator.alloc(u8, capacity);
        errdefer self.allocator.free(suffixes);
        const reversed = try self.allocator.alloc(u8, capacity);
        errdefer self.allocator.free(reversed);
        for (suffixes[0..literal_count], 0..) |*suffix, value|
            suffix.* = @intCast(value);
        self.prefixes = prefixes;
        self.suffixes = suffixes;
        self.reversed = reversed;
        self.header = parsed;
        self.code_bits = initial_code_bits;
        self.max_code = maxCode(initial_code_bits, parsed.max_code_bits, capacity);
        self.next_code = if (parsed.block_mode) block_first_code else literal_count;
    }

    fn prepareString(self: *Decoder, encoded_code: u16) Error!void {
        if (self.previous_code == null) {
            if (encoded_code >= literal_count) return error.InvalidCompressStream;
            self.first_byte = @intCast(encoded_code);
            self.reversed[0] = self.first_byte;
            self.reversed_len = 1;
            self.reversed_index = 1;
            try self.checkOutputAddition(1);
            self.previous_code = encoded_code;
            return;
        }

        if (encoded_code > self.next_code or encoded_code >= self.prefixes.len)
            return error.InvalidCompressStream;
        var code = encoded_code;
        var reversed_len: usize = 0;
        if (code == self.next_code) {
            if (self.next_code >= self.prefixes.len) return error.InvalidCompressStream;
            self.reversed[reversed_len] = self.first_byte;
            reversed_len += 1;
            code = self.previous_code.?;
        }
        while (code >= literal_count) {
            if (code >= self.next_code or reversed_len >= self.reversed.len)
                return error.InvalidCompressStream;
            self.reversed[reversed_len] = self.suffixes[code];
            reversed_len += 1;
            code = self.prefixes[code];
        }
        if (reversed_len >= self.reversed.len) return error.InvalidCompressStream;
        self.first_byte = self.suffixes[code];
        self.reversed[reversed_len] = self.first_byte;
        reversed_len += 1;
        try self.checkOutputAddition(reversed_len);

        if (self.next_code < self.prefixes.len) {
            self.prefixes[self.next_code] = self.previous_code.?;
            self.suffixes[self.next_code] = self.first_byte;
            self.next_code += 1;
        }
        self.previous_code = encoded_code;
        self.reversed_len = reversed_len;
        self.reversed_index = reversed_len;
    }

    fn ensureBits(
        self: *Decoder,
        wanted: u5,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        while (self.bit_count < wanted and input_read.* < input.len) {
            self.bit_buffer |= @as(u32, input[input_read.*]) << @intCast(self.bit_count);
            self.bit_count += 8;
            input_read.* += 1;
            try self.recordInput(1);
        }
        return self.bit_count >= wanted;
    }

    fn readCode(self: *Decoder, width: u5) Error!u16 {
        const mask = (@as(u32, 1) << width) - 1;
        const code: u16 = @intCast(self.bit_buffer & mask);
        self.bit_buffer >>= @intCast(width);
        self.bit_count -= @intCast(width);
        self.payload_bits_read = try checkedAdd(self.payload_bits_read, width);
        return code;
    }

    fn beginAlignment(self: *Decoder, action: AlignmentAction) Error!void {
        const group_bits = @as(usize, self.code_bits) * 8;
        const relative = self.payload_bits_read - self.group_base_bits;
        const rounded = std.math.add(usize, relative, group_bits - 1) catch
            return error.IntegerOverflow;
        const aligned_relative = rounded / group_bits * group_bits;
        const target = std.math.add(usize, self.group_base_bits, aligned_relative) catch
            return error.IntegerOverflow;
        self.alignment_remaining = target - self.payload_bits_read;
        self.alignment_action = action;
    }

    fn skipAlignment(
        self: *Decoder,
        input: []const u8,
        input_read: *usize,
    ) Error!bool {
        while (self.alignment_remaining != 0) {
            if (self.bit_count != 0) {
                const take: u6 = @intCast(@min(
                    self.alignment_remaining,
                    self.bit_count,
                ));
                self.bit_buffer >>= @intCast(take);
                self.bit_count -= take;
                self.alignment_remaining -= take;
                self.payload_bits_read = try checkedAdd(
                    self.payload_bits_read,
                    take,
                );
                continue;
            }
            if (self.alignment_remaining >= 8 and input_read.* < input.len) {
                const take = @min(
                    self.alignment_remaining / 8,
                    input.len - input_read.*,
                );
                input_read.* += take;
                try self.recordInput(take);
                const bits = std.math.mul(usize, take, 8) catch
                    return error.IntegerOverflow;
                self.alignment_remaining -= bits;
                self.payload_bits_read = try checkedAdd(
                    self.payload_bits_read,
                    bits,
                );
                continue;
            }
            if (input_read.* == input.len) return false;
            self.bit_buffer = input[input_read.*];
            self.bit_count = 8;
            input_read.* += 1;
            try self.recordInput(1);
        }
        self.group_base_bits = self.payload_bits_read;
        return true;
    }

    fn applyAlignment(self: *Decoder) Error!void {
        switch (self.alignment_action) {
            .none => unreachable,
            .grow => {
                self.code_bits += 1;
                self.max_code = maxCode(
                    self.code_bits,
                    self.header.?.max_code_bits,
                    self.prefixes.len,
                );
                self.width_growth_count = try checkedAdd(
                    self.width_growth_count,
                    1,
                );
            },
            .clear => {
                self.code_bits = initial_code_bits;
                self.max_code = maxCode(
                    self.code_bits,
                    self.header.?.max_code_bits,
                    self.prefixes.len,
                );
                self.next_code = block_first_code;
                self.previous_code = null;
                self.clear_count = try checkedAdd(self.clear_count, 1);
            },
        }
        self.alignment_action = .none;
    }

    fn checkOutputAddition(self: *const Decoder, additional: usize) Error!void {
        const next = std.math.add(usize, self.total_output, additional) catch
            return error.IntegerOverflow;
        if (next > self.options.max_output_len) return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (next > expected) return error.SizeMismatch;
    }

    fn complete(self: *Decoder) Error!void {
        if (self.options.expected_output_len) |expected|
            if (self.total_output != expected) return error.SizeMismatch;
        self.phase = .done;
    }

    fn recordInput(self: *Decoder, count: usize) Error!void {
        self.total_input = try checkedAdd(self.total_input, count);
    }

    fn freeDictionary(self: *Decoder) void {
        if (self.prefixes.len != 0) self.allocator.free(self.prefixes);
        if (self.suffixes.len != 0) self.allocator.free(self.suffixes);
        if (self.reversed.len != 0) self.allocator.free(self.reversed);
        self.prefixes = &.{};
        self.suffixes = &.{};
        self.reversed = &.{};
    }

    fn maxCode(width: u5, max_width: u5, capacity: usize) usize {
        return if (width == max_width) capacity else (@as(usize, 1) << width) - 1;
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
