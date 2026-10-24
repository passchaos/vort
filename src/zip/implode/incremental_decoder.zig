const std = @import("std");
const core = @import("../../core.zig");

pub const Error = error{
    InvalidImplodeStream,
    TruncatedImplodeInput,
    ImplodeSizeMismatch,
    ImplodeTrailingData,
    OutputLimitExceeded,
    IntegerOverflow,
};

pub const Dictionary = enum {
    small_4k,
    large_8k,
};

const max_tree_bits: usize = 16;
const literal_symbols: usize = 256;
const length_symbols: usize = 64;
const distance_symbols: usize = 64;
const length_direct_bits: u5 = 8;
const max_window_size: usize = 8 * 1024;

const Tree = struct {
    starts: [max_tree_bits + 1]u16 = @splat(0),
    counts: [max_tree_bits + 1]u16 = @splat(0),
    poses: [max_tree_bits + 1]u16 = @splat(0),
    symbols: [literal_symbols]u8 = @splat(0),

    fn build(lengths: []const u8) Error!Tree {
        var tree = Tree{};
        for (lengths) |length| {
            if (length == 0 or length > max_tree_bits)
                return error.InvalidImplodeStream;
            tree.counts[length] += 1;
        }
        var start_position: u32 = 1 << max_tree_bits;
        var symbol_position: u16 = 0;
        for (1..max_tree_bits + 1) |length| {
            const range = @as(u32, tree.counts[length]) << @intCast(max_tree_bits - length);
            if (start_position < range) return error.InvalidImplodeStream;
            start_position -= range;
            tree.starts[length] = @intCast(start_position >> @intCast(max_tree_bits - length));
            tree.poses[length] = symbol_position;
            symbol_position += tree.counts[length];
        }
        if (start_position != 0) return error.InvalidImplodeStream;
        for (1..max_tree_bits + 1) |length| {
            var position = tree.poses[length];
            var symbol = lengths.len;
            while (symbol != 0) {
                symbol -= 1;
                if (lengths[symbol] == length) {
                    tree.symbols[position] = @intCast(symbol);
                    position += 1;
                }
            }
        }
        return tree;
    }
};

pub const Workspace = struct {
    literal_tree: Tree = .{},
    length_tree: Tree = .{},
    distance_tree: Tree = .{},
    tree_lengths: [literal_symbols]u8 = @splat(0),
    history: [max_window_size]u8 = undefined,
};

pub const Decoder = struct {
    options: DecodeOptions,
    workspace: *Workspace,
    dictionary: Dictionary,
    literal_tree_enabled: bool,
    phase: Phase,
    tree_kind: TreeKind,
    tree_records_remaining: u16 = 0,
    tree_index: usize = 0,
    reservoir: u64 = 0,
    bit_count: u8 = 0,
    huffman: HuffmanState = .{},
    low_distance: usize = 0,
    match_distance: usize = 0,
    match_length: usize = 0,
    match_remaining: usize = 0,
    pending_literal: u8 = 0,
    history_pos: usize = 0,
    input_finished: bool = false,
    total_input: usize = 0,
    total_output: usize = 0,
    last_error_name: []const u8 = "",
    last_error_phase: Phase,

    const Self = @This();

    pub const DecodeOptions = struct {
        max_output_len: usize = std.math.maxInt(usize),
        expected_output_len: ?usize = null,
    };

    pub const Phase = enum {
        tree_record_count,
        tree_record,
        token,
        literal_raw,
        literal_tree,
        distance_low,
        distance_symbol,
        length_symbol,
        length_extra,
        emit_literal,
        match_copy,
        done,
        failed,
    };

    pub const TreeKind = enum {
        literal,
        length,
        distance,
    };

    const HuffmanState = struct {
        code: u16 = 0,
        length: u5 = 1,

        fn reset(self: *HuffmanState) void {
            self.* = .{};
        }
    };

    pub const Snapshot = struct {
        phase: Phase,
        input_read: usize,
        output_written: usize,
        tree_kind: TreeKind,
        tree_symbols_received: usize,
        pending_match_bytes: usize,
        input_finished: bool,
        last_error_name: []const u8,
        last_error_phase: Phase,
    };

    pub fn init(workspace: *Workspace, flags: u16) Self {
        return initWithOptions(workspace, flags, .{});
    }

    pub fn initWithOptions(
        workspace: *Workspace,
        flags: u16,
        options: DecodeOptions,
    ) Self {
        const literal_tree_enabled = flags & 0x0004 != 0;
        const first_kind: TreeKind = if (literal_tree_enabled) .literal else .length;
        const first_phase: Phase = .tree_record_count;
        var self: Self = .{
            .options = options,
            .workspace = workspace,
            .dictionary = if (flags & 0x0002 != 0) .large_8k else .small_4k,
            .literal_tree_enabled = literal_tree_enabled,
            .phase = first_phase,
            .tree_kind = first_kind,
            .last_error_phase = first_phase,
        };
        self.clearWorkspace();
        return self;
    }

    pub fn reset(self: *Self) void {
        const options = self.options;
        const workspace = self.workspace;
        const flags: u16 = (@as(u16, @intFromBool(self.dictionary == .large_8k)) << 1) |
            (@as(u16, @intFromBool(self.literal_tree_enabled)) << 2);
        self.* = initWithOptions(workspace, flags, options);
    }

    pub fn finish(self: *Self) void {
        self.input_finished = true;
    }

    pub fn setExpectedOutputLen(self: *Self, expected: usize) Error!void {
        if (expected < self.total_output or expected > self.options.max_output_len)
            return error.ImplodeSizeMismatch;
        if (self.options.expected_output_len) |current|
            if (current != expected) return error.ImplodeSizeMismatch;
        self.options.expected_output_len = expected;
    }

    pub fn snapshot(self: *const Self) Snapshot {
        return .{
            .phase = self.phase,
            .input_read = self.total_input,
            .output_written = self.total_output,
            .tree_kind = self.tree_kind,
            .tree_symbols_received = self.tree_index,
            .pending_match_bytes = self.match_remaining,
            .input_finished = self.input_finished,
            .last_error_name = self.last_error_name,
            .last_error_phase = self.last_error_phase,
        };
    }

    pub fn diagnostics(self: *const Self) core.StreamingDiagnostics {
        return .{
            .phase_name = @tagName(self.phase),
            .header_received = self.total_input,
            .frame_input_read = self.total_input,
            .output_written = self.total_output,
            .expected_output_len = core.stream_count.fromOptionalLocal(self.options.expected_output_len),
            .payload_remaining = self.match_remaining,
            .last_error_name = self.last_error_name,
            .last_error_phase_name = if (self.last_error_name.len == 0) "" else @tagName(self.last_error_phase),
            .recoverability_hint_name = if (self.phase == .failed) "payload_corrupt" else "none",
        };
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .failed) return error.InvalidImplodeStream;
        return self.stepInner(input, output) catch |err| {
            return self.fail(err);
        };
    }

    fn stepInner(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.phase == .done) {
            if (input.len != 0) return error.ImplodeTrailingData;
            return .{ .status = .done };
        }
        if (self.input_finished and input.len != 0) return error.ImplodeTrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) switch (self.phase) {
            .tree_record_count => {
                const encoded_count = self.readAlignedByte(input, &input_read) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.tree_records_remaining = @as(u16, encoded_count) + 1;
                self.tree_index = 0;
                @memset(&self.workspace.tree_lengths, 0);
                self.phase = .tree_record;
            },
            .tree_record => {
                const descriptor = self.readAlignedByte(input, &input_read) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                const length = (descriptor & 0x0f) + 1;
                const repetitions = @as(usize, descriptor >> 4) + 1;
                const symbol_count = self.treeSymbolCount();
                if (self.tree_index + repetitions > symbol_count)
                    return error.InvalidImplodeStream;
                @memset(
                    self.workspace.tree_lengths[self.tree_index .. self.tree_index + repetitions],
                    length,
                );
                self.tree_index += repetitions;
                self.tree_records_remaining -= 1;
                if (self.tree_records_remaining == 0) {
                    if (self.tree_index != symbol_count)
                        return error.InvalidImplodeStream;
                    try self.commitTree(symbol_count);
                    self.advanceTree();
                }
            },
            .token => {
                if (self.options.expected_output_len) |expected| {
                    if (self.total_output == expected) {
                        if (input_read != input.len) return error.ImplodeTrailingData;
                        return self.atInputBoundary(input_read, output_written);
                    }
                }
                const literal = self.readBits(input, &input_read, 1) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.phase = if (literal != 0)
                    if (self.literal_tree_enabled) .literal_tree else .literal_raw
                else
                    .distance_low;
            },
            .literal_raw => {
                const byte = self.readBits(input, &input_read, 8) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                try self.scheduleLiteral(@truncate(byte));
            },
            .literal_tree => {
                const symbol = (try self.decodeTree(
                    &self.workspace.literal_tree,
                    input,
                    &input_read,
                )) orelse return self.needInputOrTruncated(input_read, output_written);
                try self.scheduleLiteral(symbol);
            },
            .distance_low => {
                const low = self.readBits(input, &input_read, self.distanceBits()) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.low_distance = low;
                self.phase = .distance_symbol;
            },
            .distance_symbol => {
                const symbol = (try self.decodeTree(
                    &self.workspace.distance_tree,
                    input,
                    &input_read,
                )) orelse return self.needInputOrTruncated(input_read, output_written);
                self.match_distance = (@as(usize, symbol) << @intCast(self.distanceBits())) |
                    self.low_distance;
                self.phase = .length_symbol;
            },
            .length_symbol => {
                const symbol = (try self.decodeTree(
                    &self.workspace.length_tree,
                    input,
                    &input_read,
                )) orelse return self.needInputOrTruncated(input_read, output_written);
                self.match_length = symbol;
                if (symbol == length_symbols - 1) {
                    self.phase = .length_extra;
                } else {
                    try self.scheduleMatch();
                }
            },
            .length_extra => {
                const extra = self.readBits(input, &input_read, length_direct_bits) orelse
                    return self.needInputOrTruncated(input_read, output_written);
                self.match_length += extra;
                try self.scheduleMatch();
            },
            .emit_literal => {
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                try self.emitByte(self.pending_literal, output, &output_written);
                self.phase = .token;
            },
            .match_copy => {
                if (self.match_remaining == 0) {
                    self.phase = .token;
                    continue;
                }
                if (output_written == output.len)
                    return result(input_read, output_written, .need_output);
                const distance = self.match_distance + 1;
                const byte: u8 = if (distance > self.total_output)
                    0
                else
                    self.workspace.history[
                        (self.history_pos + self.windowSize() - distance) % self.windowSize()
                    ];
                try self.emitByte(byte, output, &output_written);
                self.match_remaining -= 1;
            },
            .done => {
                if (input_read != input.len) return error.ImplodeTrailingData;
                return result(input_read, output_written, .done);
            },
            .failed => return error.InvalidImplodeStream,
        };
    }

    fn commitTree(self: *Self, symbol_count: usize) Error!void {
        const tree = try Tree.build(self.workspace.tree_lengths[0..symbol_count]);
        switch (self.tree_kind) {
            .literal => self.workspace.literal_tree = tree,
            .length => self.workspace.length_tree = tree,
            .distance => self.workspace.distance_tree = tree,
        }
    }

    fn advanceTree(self: *Self) void {
        switch (self.tree_kind) {
            .literal => self.tree_kind = .length,
            .length => self.tree_kind = .distance,
            .distance => {
                self.phase = .token;
                return;
            },
        }
        self.phase = .tree_record_count;
    }

    fn treeSymbolCount(self: *const Self) usize {
        return switch (self.tree_kind) {
            .literal => literal_symbols,
            .length => length_symbols,
            .distance => distance_symbols,
        };
    }

    fn decodeTree(
        self: *Self,
        tree: *const Tree,
        input: []const u8,
        input_read: *usize,
    ) Error!?u8 {
        while (self.huffman.length <= max_tree_bits) {
            const bit = self.readBits(input, input_read, 1) orelse return null;
            self.huffman.code = (self.huffman.code << 1) | bit;
            const length = self.huffman.length;
            const start = tree.starts[length];
            const count = tree.counts[length];
            if (self.huffman.code >= start and self.huffman.code - start < count) {
                const symbol = tree.symbols[
                    tree.poses[length] + self.huffman.code - start
                ];
                self.huffman.reset();
                return symbol;
            }
            self.huffman.length += 1;
        }
        return error.InvalidImplodeStream;
    }

    fn scheduleLiteral(self: *Self, byte: u8) Error!void {
        if (self.total_output == self.options.max_output_len)
            return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (self.total_output == expected) return error.ImplodeSizeMismatch;
        self.pending_literal = byte;
        self.phase = .emit_literal;
    }

    fn scheduleMatch(self: *Self) Error!void {
        self.match_remaining = self.match_length + self.minimumLength();
        if (self.match_remaining > self.options.max_output_len -| self.total_output)
            return error.OutputLimitExceeded;
        if (self.options.expected_output_len) |expected|
            if (self.match_remaining > expected -| self.total_output)
                return error.ImplodeSizeMismatch;
        self.phase = .match_copy;
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

    fn readAlignedByte(self: *Self, input: []const u8, input_read: *usize) ?u8 {
        if (self.bit_count != 0) return null;
        if (input_read.* == input.len) return null;
        const byte = input[input_read.*];
        input_read.* += 1;
        self.total_input += 1;
        return byte;
    }

    fn readBits(self: *Self, input: []const u8, input_read: *usize, count: u5) ?u16 {
        while (self.bit_count < count) {
            if (input_read.* == input.len) return null;
            self.reservoir |= @as(u64, input[input_read.*]) << @intCast(self.bit_count);
            self.bit_count += 8;
            input_read.* += 1;
            self.total_input += 1;
        }
        const value: u16 = @truncate(self.reservoir & ((@as(u64, 1) << @intCast(count)) - 1));
        self.reservoir >>= @intCast(count);
        self.bit_count -= @intCast(count);
        return value;
    }

    fn needInputOrTruncated(
        self: *Self,
        input_read: usize,
        output_written: usize,
    ) Error!core.StepResult {
        if (self.input_finished) return error.TruncatedImplodeInput;
        return result(input_read, output_written, .need_input);
    }

    fn atInputBoundary(
        self: *Self,
        input_read: usize,
        output_written: usize,
    ) Error!core.StepResult {
        if (!self.input_finished)
            return result(input_read, output_written, .need_input);
        const expected = self.options.expected_output_len orelse
            return error.ImplodeSizeMismatch;
        if (self.total_output != expected) return error.ImplodeSizeMismatch;
        self.phase = .done;
        return result(input_read, output_written, .done);
    }

    fn distanceBits(self: *const Self) u5 {
        return if (self.dictionary == .large_8k) 7 else 6;
    }

    fn minimumLength(self: *const Self) usize {
        return if (self.literal_tree_enabled) 3 else 2;
    }

    fn windowSize(self: *const Self) usize {
        return if (self.dictionary == .large_8k) 8192 else 4096;
    }

    fn clearWorkspace(self: *Self) void {
        @memset(&self.workspace.tree_lengths, 0);
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
