const std = @import("std");
const core = @import("../../core.zig");

pub const Error = error{
    InvalidReduceStream,
    TruncatedReduceInput,
    ReduceSizeMismatch,
    ReduceTrailingData,
    OutputLimitExceeded,
    IntegerOverflow,
};

pub const Factor = enum(u3) {
    factor_1 = 1,
    factor_2 = 2,
    factor_3 = 3,
    factor_4 = 4,
};

const dle: u8 = 144;
const max_window_size: usize = 1 << 12;

const Followers = struct {
    counts: [256]u8 = @splat(0),
    symbols: [256][32]u8 = @splat(@splat(0)),
};

pub const Workspace = struct {
    followers: Followers = .{},
    history: [max_window_size]u8 = undefined,
};

fn followerBits(count: u8) u4 {
    if (count <= 1) return 0;
    return @intCast(std.math.log2_int_ceil(u8, count));
}

/// Caller-output, bit-progressive ZIP Reduce decoder shared by factors 1...4.
///
/// Reduce has no in-band end marker. The containing format must call `finish`
/// at the compressed boundary and then drain `step("", output)` to `.done`.
pub const Decoder = struct {
    options: DecodeOptions,
    workspace: *Workspace,
    factor: Factor,
    phase: Phase = .header_count,
    header_context: u8 = 255,
    header_symbol_index: u8 = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    last_character: u8 = 0,
    command_state: CommandState = .normal,
    match_control: u8 = 0,
    match_length: usize = 0,
    match_distance: usize = 0,
    match_remaining: usize = 0,
    pending_literal: u8 = 0,
    history_pos: usize = 0,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase = .header_count,

    const Self = @This();

    pub const DecodeOptions = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };

    pub const Phase = enum {
        header_count,
        header_symbol,
        symbol_mode,
        symbol_raw,
        symbol_index,
        emit_literal,
        match_copy,
        done,
        failed,
    };

    pub const CommandState = enum {
        normal,
        after_dle,
        length_extra,
        distance,
    };

    pub const Snapshot = struct {
        phase: Phase,
        factor: Factor,
        input_read: usize,
        output_written: usize,
        header_contexts_remaining: usize,
        command_state: CommandState,
        pending_match_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(workspace: *Workspace, factor: Factor) Self {
        return initWithOptions(workspace, factor, .{});
    }

    pub fn initWithOptions(
        workspace: *Workspace,
        factor: Factor,
        options: DecodeOptions,
    ) Self {
        var self: Self = .{
            .options = options,
            .workspace = workspace,
            .factor = factor,
        };
        self.clearWorkspace();
        return self;
    }

    pub fn reset(self: *Self) void {
        const options = self.options;
        const workspace = self.workspace;
        const factor = self.factor;
        self.* = .{
            .options = options,
            .workspace = workspace,
            .factor = factor,
        };
        self.clearWorkspace();
    }

    pub fn finish(self: *Self) void {
        self.input_finished = true;
    }

    /// Adds an exact output pledge before finishing a previously unpledged
    /// stream. Container adapters use this on a transactional decoder clone.
    pub fn setExpectedOutputLen(self: *Self, expected: usize) Error!void {
        if (expected < self.total_output or expected > self.options.max_output_len)
            return error.ReduceSizeMismatch;
        if (self.options.expected_output_len) |current|
            if (current != expected) return error.ReduceSizeMismatch;
        self.options.expected_output_len = expected;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .factor = self.factor,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .header_contexts_remaining = switch (self.phase) {
                .header_count, .header_symbol => @as(usize, self.header_context) + 1,
                else => 0,
            },
            .command_state = self.command_state,
            .pending_match_bytes = self.match_remaining,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .header_received = 256 - self.snapshot().header_contexts_remaining,
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = self.options.expected_output_len,
            .payload_remaining = self.match_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (self.phase == .failed) "payload_corrupt" else "none",
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.InvalidReduceStream;
        return self.stepInner(input, output) catch |err| {
            return self.fail(err);
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.ReduceTrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.ReduceTrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .header_count => {
                const count = self.readBits(input, &input_read, 6) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                if (count > 32) return error.InvalidReduceStream;
                self.workspace.followers.counts[self.header_context] = count;
                self.header_symbol_index = 0;
                if (count == 0) {
                    self.advanceHeader();
                } else {
                    self.phase = .header_symbol;
                }
            },
            .header_symbol => {
                const symbol = self.readBits(input, &input_read, 8) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.workspace.followers.symbols[self.header_context][self.header_symbol_index] = symbol;
                self.header_symbol_index += 1;
                if (self.header_symbol_index == self.workspace.followers.counts[self.header_context])
                    self.advanceHeader();
            },
            .symbol_mode => {
                if (self.options.expected_output_len) |expected| {
                    if (self.total_output == expected) {
                        if (input_read != input.len) return error.ReduceTrailingData;
                        return self.atInputBoundary(input_read, output_written);
                    }
                }
                const count = self.workspace.followers.counts[self.last_character];
                if (count == 0) {
                    self.phase = .symbol_raw;
                    continue;
                }
                const raw = self.readBits(input, &input_read, 1) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.phase = if (raw != 0) .symbol_raw else .symbol_index;
            },
            .symbol_raw => {
                const byte = self.readBits(input, &input_read, 8) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                try self.acceptReducedByte(byte);
            },
            .symbol_index => {
                const count = self.workspace.followers.counts[self.last_character];
                const index = self.readBits(input, &input_read, followerBits(count)) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                if (index >= count) return error.InvalidReduceStream;
                try self.acceptReducedByte(
                    self.workspace.followers.symbols[self.last_character][index],
                );
            },
            .emit_literal => {
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                try self.emitByte(self.pending_literal, output, &output_written);
                self.phase = .symbol_mode;
            },
            .match_copy => {
                if (self.match_remaining == 0) {
                    self.phase = .symbol_mode;
                    continue;
                }
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                const byte: u8 = if (self.match_distance > self.total_output)
                    0
                else
                    self.workspace.history[
                        (self.history_pos + self.windowSize() - self.match_distance) % self.windowSize()
                    ];
                try self.emitByte(byte, output, &output_written);
                self.match_remaining -= 1;
            },
            .done => {
                if (input_read != input.len) return error.ReduceTrailingData;
                return result(input_read, output_written, .done);
            },
            .failed => return error.InvalidReduceStream,
        };
    }

    fn advanceHeader(self: *Self) void {
        if (self.header_context == 0) {
            self.phase = .symbol_mode;
        } else {
            self.header_context -= 1;
            self.phase = .header_count;
        }
    }

    fn acceptReducedByte(self: *Self, byte: u8) Error!void {
        self.last_character = byte;
        switch (self.command_state) {
            .normal => {
                if (byte == dle) {
                    self.command_state = .after_dle;
                    self.phase = .symbol_mode;
                } else {
                    try self.scheduleLiteral(byte);
                }
            },
            .after_dle => {
                if (byte == 0) {
                    self.command_state = .normal;
                    try self.scheduleLiteral(dle);
                } else {
                    self.match_control = byte;
                    self.match_length = byte & self.lengthMask();
                    self.command_state = if (self.match_length == self.lengthMask())
                        .length_extra
                    else
                        .distance;
                    self.phase = .symbol_mode;
                }
            },
            .length_extra => {
                self.match_length += byte;
                self.command_state = .distance;
                self.phase = .symbol_mode;
            },
            .distance => {
                self.match_distance = (@as(usize, self.match_control >> @intCast(self.lengthBits())) << 8) + byte + 1;
                self.match_remaining = self.match_length + 3;
                if (self.match_remaining > self.options.max_output_len -| self.total_output)
                    return error.OutputLimitExceeded;
                if (self.options.expected_output_len) |expected|
                    if (self.match_remaining > expected -| self.total_output)
                        return error.ReduceSizeMismatch;
                self.command_state = .normal;
                self.phase = .match_copy;
            },
        }
    }

    fn scheduleLiteral(self: *Self, byte: u8) Error!void {
        if (self.total_output == self.options.max_output_len)
            return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (self.total_output == expected) return error.ReduceSizeMismatch;
        self.pending_literal = byte;
        self.phase = .emit_literal;
    }

    fn emitByte(
        self: *Self,
        byte: u8,
        output: []u8,
        output_written: *usize,
    ) Error!void {
        output[output_written.*] = byte;
        output_written.* += 1;
        self.workspace.history[self.history_pos] = byte;
        self.history_pos = (self.history_pos + 1) % self.windowSize();
        self.total_output = std.math.add(usize, self.total_output, 1) catch
            return error.IntegerOverflow;
    }

    fn readBits(self: *Self, input: []const u8, input_read: *usize, count: u4) ?u8 {
        if (count == 0) return 0;
        while (self.bit_count < count) {
            if (input_read.* == input.len) return null;
            self.reservoir |= @as(u64, input[input_read.*]) << @intCast(self.bit_count);
            self.bit_count += 8;
            input_read.* += 1;
            self.total_input += 1;
        }
        const value: u8 = @truncate(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.bit_count -= count;
        return value;
    }

    fn needInputOrTruncated(
        self: *Self,
        input_read: usize,
        output_written: usize,
    ) Error!core.StepResult {
        if (self.input_finished) return error.TruncatedReduceInput;
        return result(input_read, output_written, .need_input);
    }

    fn atInputBoundary(
        self: *Self,
        input_read: usize,
        output_written: usize,
    ) Error!core.StepResult {
        if (!self.input_finished)
            return result(input_read, output_written, .need_input);
        if (self.command_state != .normal) return error.ReduceSizeMismatch;
        if (self.options.expected_output_len) |expected|
            if (self.total_output != expected) return error.ReduceSizeMismatch;
        self.phase = .done;
        return result(input_read, output_written, .done);
    }

    fn lengthBits(self: *const Self) u4 {
        return 8 - @as(u4, @intFromEnum(self.factor));
    }

    fn lengthMask(self: *const Self) u8 {
        return (@as(u8, 1) << @intCast(self.lengthBits())) - 1;
    }

    fn windowSize(self: *const Self) usize {
        return @as(usize, 1) << @intCast(8 + @as(usize, @intFromEnum(self.factor)));
    }

    fn clearWorkspace(self: *Self) void {
        @memset(&self.workspace.followers.counts, 0);
    }

    fn fail(self: *Self, err: Error) Error {
        if (self.phase != .failed) {
            self.last_error_name = @errorName(err);
            self.last_error_phase = self.phase;
            self.phase = .failed;
        }
        return err;
    }

    fn result(
        input_read: usize,
        output_written: usize,
        status: core.StepResult.Status,
    ) core.StepResult {
        return .{
            .progress = .{ .input_read = input_read, .output_written = output_written },
            .status = status,
        };
    }
};
