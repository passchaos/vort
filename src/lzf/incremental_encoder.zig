//! Block-bounded incremental encoder for standard LZF `ZV` streams.

const std = @import("std");
const block = @import("block.zig");
const core = @import("../core.zig");
const frame = @import("frame.zig");

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    plain: std.ArrayList(u8) = .empty,
    compressed: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    finishing: bool = false,
    eof_written: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    stored_block_count: usize = 0,
    compressed_block_count: usize = 0,

    pub const Error = frame.Error || std.mem.Allocator.Error;
    pub const Options = struct {
        block_size: usize = frame.max_block_size,
        eof_marker: bool = false,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = frame.max_block_size + 7,
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        buffered_input: usize,
        pending_output: usize,
        block_count: usize,
        stored_block_count: usize,
        compressed_block_count: usize,
        finishing: bool,
        eof_written: bool,
        done: bool,
        retained_input_capacity: usize,
        retained_compressed_capacity: usize,
        retained_output_capacity: usize,
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        try validateOptions(options);
        return .{ .allocator = allocator, .options = options };
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        var encoder = try initWithOptions(allocator, options);
        if (expected_input_len > options.max_input_len)
            return error.OutputLimitExceeded;
        encoder.expected_input_len = expected_input_len;
        return encoder;
    }

    pub fn deinit(self: *Encoder) void {
        self.plain.deinit(self.allocator);
        self.compressed.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        const allocator = self.allocator;
        const options = self.options;
        const expected = self.expected_input_len;
        var plain = self.plain;
        var compressed = self.compressed;
        var pending = self.pending;
        plain.clearRetainingCapacity();
        compressed.clearRetainingCapacity();
        pending.clearRetainingCapacity();
        self.* = .{
            .allocator = allocator,
            .options = options,
            .expected_input_len = expected,
            .plain = plain,
            .compressed = compressed,
            .pending = pending,
        };
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .buffered_input = self.plain.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .block_count = self.block_count,
            .stored_block_count = self.stored_block_count,
            .compressed_block_count = self.compressed_block_count,
            .finishing = self.finishing,
            .eof_written = self.eof_written,
            .done = self.done,
            .retained_input_capacity = self.plain.capacity,
            .retained_compressed_capacity = self.compressed.capacity,
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
                const room = self.options.block_size - self.plain.items.len;
                const take = @min(room, input.len - input_read);
                const next_input = try checkedAdd(self.total_input, take);
                if (next_input > self.options.max_input_len)
                    return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (next_input > expected) return error.SizeMismatch;
                try self.plain.appendSlice(
                    self.allocator,
                    input[input_read..][0..take],
                );
                input_read += take;
                self.total_input = next_input;
            }
            if (self.plain.items.len == self.options.block_size) {
                try self.emitBlock();
                continue;
            }
            if (input_read != input.len) continue;

            if (self.finishing) {
                if (self.expected_input_len) |expected|
                    if (self.total_input != expected) return error.SizeMismatch;
                if (self.plain.items.len != 0) {
                    try self.emitBlock();
                    continue;
                }
                if (self.options.eof_marker and !self.eof_written) {
                    try self.pending.append(self.allocator, 0);
                    try self.checkPendingLimit();
                    self.eof_written = true;
                    continue;
                }
                self.done = true;
                return result(input_read, output_written, .done);
            }
            return result(input_read, output_written, .need_input);
        }
    }

    fn emitBlock(self: *Encoder) Error!void {
        std.debug.assert(self.plain.items.len != 0);
        self.compressed.clearRetainingCapacity();
        _ = try block.encodeAppend(
            self.allocator,
            &self.compressed,
            self.plain.items,
        );
        if (self.compressed.items.len < self.plain.items.len and
            self.plain.items.len - self.compressed.items.len > 2)
        {
            try self.pending.appendSlice(self.allocator, "ZV\x01");
            try appendBe16(
                self.allocator,
                &self.pending,
                @intCast(self.compressed.items.len),
            );
            try appendBe16(
                self.allocator,
                &self.pending,
                @intCast(self.plain.items.len),
            );
            try self.pending.appendSlice(self.allocator, self.compressed.items);
            self.compressed_block_count = try checkedAdd(
                self.compressed_block_count,
                1,
            );
        } else {
            try self.pending.appendSlice(self.allocator, "ZV\x00");
            try appendBe16(
                self.allocator,
                &self.pending,
                @intCast(self.plain.items.len),
            );
            try self.pending.appendSlice(self.allocator, self.plain.items);
            self.stored_block_count = try checkedAdd(self.stored_block_count, 1);
        }
        try self.checkPendingLimit();
        self.block_count = try checkedAdd(self.block_count, 1);
        self.plain.clearRetainingCapacity();
        self.compressed.clearRetainingCapacity();
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len - self.pending_offset >
            self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    fn validateOptions(options: Options) Error!void {
        if (options.block_size == 0 or options.block_size > frame.max_block_size)
            return error.InvalidLzfOptions;
        if (options.max_pending_output_len == 0)
            return error.InvalidLzfOptions;
    }

    fn appendBe16(
        allocator: std.mem.Allocator,
        output: *std.ArrayList(u8),
        value: u16,
    ) Error!void {
        var bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &bytes, value, .big);
        try output.appendSlice(allocator, &bytes);
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
