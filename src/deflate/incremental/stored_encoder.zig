const std = @import("std");
const core = @import("../../core.zig");

/// Incremental raw-DEFLATE stored-block encoder. One RFC 1951 stored block is
/// retained; encoded bytes drain through arbitrary caller output. Flush writes
/// a non-final block, while finish writes the only BFINAL block.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        plain: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        flush_requested: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            max_input_len: usize = std.math.maxInt(usize),
            block_len: usize = Codec.max_block_len,
        };
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            buffered_input: usize,
            pending_output: usize,
            flushing: bool,
            finishing: bool,
            done: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: usize) Self {
            return .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len };
        }
        pub fn deinit(self: *Self) void {
            self.plain.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.plain.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.flush_requested = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .flushing = self.flush_requested,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }
        pub fn finish(self: *Self) void {
            self.finishing = true;
            self.flush_requested = false;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.options.block_len == 0 or self.options.block_len > Codec.max_block_len) return error.InvalidBlockPlan;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
            const offered_total = std.math.add(usize, self.total_input, input.len) catch return error.IntegerOverflow;
            if (offered_total > self.options.max_input_len) return error.OutputLimitExceeded;

            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                if (self.pending_offset != self.pending.items.len) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output += n;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }

                const room = self.options.block_len - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    self.total_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                if (self.plain.items.len == self.options.block_len and input_read < input.len) {
                    try self.writeBlock(false);
                    continue;
                }
                if (self.flush_requested) {
                    if (self.plain.items.len != 0) {
                        try self.writeBlock(false);
                        continue;
                    }
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (self.finishing and !self.final_written) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    try self.writeBlock(true);
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

        fn writeBlock(self: *Self, final: bool) Error!void {
            try Codec.writeBlock(self.allocator, &self.pending, self.plain.items, final);
            self.plain.clearRetainingCapacity();
        }
        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
