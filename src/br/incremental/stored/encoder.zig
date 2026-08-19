const std = @import("std");
const core = @import("../../../core.zig");

/// Build an incremental encoder for Brotli stored/uncompressed streams. Input
/// is bounded to one format meta-block, while encoded bytes are drained through
/// arbitrary caller output without rebuilding previous blocks.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        codec_state: Codec.State = .{},
        plain: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        prefix_written: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            stream: Codec.StreamOptions = .{},
            max_input_len: usize = std.math.maxInt(usize),
            block_len: usize = 64 * 1024,
        };
        pub const Snapshot = struct { input_read: usize, output_written: usize, buffered_input: usize, pending_output: usize, finishing: bool, done: bool };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn deinit(self: *Self) void {
            self.plain.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            self.plain.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.codec_state = .{};
            self.pending_offset = 0;
            self.prefix_written = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.finishing = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.options.block_len == 0 or self.options.block_len > Codec.max_block_len) return error.InvalidBlockPlan;
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
                if (!self.prefix_written) {
                    try Codec.writePrefix(self.allocator, &self.pending, &self.codec_state, self.options.stream);
                    self.prefix_written = true;
                    continue;
                }
                const room = self.options.block_len - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const total = std.math.add(usize, self.total_input, n) catch return error.IntegerOverflow;
                    if (total > self.options.max_input_len) return error.OutputLimitExceeded;
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    self.total_input = total;
                }
                if (self.plain.items.len == self.options.block_len or (self.finishing and self.plain.items.len != 0)) {
                    try Codec.writeBlock(self.allocator, &self.pending, &self.codec_state, self.plain.items);
                    self.plain.clearRetainingCapacity();
                    continue;
                }
                if (self.finishing and !self.final_written) {
                    try Codec.writeFinal(self.allocator, &self.pending, &self.codec_state);
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

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
