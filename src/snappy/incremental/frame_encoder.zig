const std = @import("std");
const core = @import("../../core.zig");

/// Build a bounded incremental Snappy framed encoder. Input is chunked at the
/// format's 64 KiB boundary; complete encoded chunks are drained through any
/// caller-owned output size before additional input is accepted.
pub fn Encoder(comptime BlockEncoder: type, comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        block_encoder: BlockEncoder,
        plain: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        identifier_written: bool = false,
        flush_requested: bool = false,
        finishing: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        stream_input: usize = 0,
        stream_output: usize = 0,
        stream_count: usize = 0,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct { max_input_len: usize = std.math.maxInt(usize) };
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            current_input: usize,
            current_output: usize,
            buffered_input: usize,
            pending_output: usize,
            stream_count: usize,
            stream_index: usize,
            finishing: bool,
            done: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options, .block_encoder = BlockEncoder.init(allocator) };
        }
        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: usize) Self {
            return .{ .allocator = allocator, .options = options, .block_encoder = BlockEncoder.init(allocator), .expected_input_len = expected_input_len };
        }
        pub fn deinit(self: *Self) void {
            self.block_encoder.deinit();
            self.plain.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            const expected_input_len = self.expected_input_len;
            self.stream_input = 0;
            self.stream_output = 0;
            self.stream_count = 0;
            self.resetStream(self.options, expected_input_len);
        }
        fn resetStream(self: *Self, options: Options, expected_input_len: ?usize) void {
            self.options = options;
            self.plain.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            self.pending_offset = 0;
            self.identifier_written = false;
            self.flush_requested = false;
            self.finishing = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
            self.expected_input_len = expected_input_len;
        }
        pub fn nextStream(self: *Self, options: Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            self.resetStream(options, null);
        }
        pub fn nextStreamExactSize(self: *Self, options: Options, expected_input_len: usize) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            self.resetStream(options, expected_input_len);
        }
        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.total_input,
                .output_written = self.stream_output,
                .current_input = self.total_input,
                .current_output = self.total_output,
                .buffered_input = self.plain.items.len,
                .pending_output = self.pending.items.len - self.pending_offset,
                .stream_count = self.stream_count,
                .stream_index = if (self.done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn finish(self: *Self) Error!void {
            self.finishing = true;
            self.flush_requested = false;
        }
        /// Publish the buffered bytes as a complete framed Snappy chunk without
        /// ending the stream. Empty repeated flushes are idempotent.
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
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
                    self.stream_output += n;
                    if (self.pending_offset != self.pending.items.len) return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }

                if (!self.identifier_written) {
                    try Codec.writeIdentifier(self.allocator, &self.pending);
                    self.identifier_written = true;
                    continue;
                }

                const room = Codec.max_chunk_len - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const next_total = std.math.add(usize, self.total_input, n) catch return error.IntegerOverflow;
                    if (next_total > self.options.max_input_len) return error.OutputLimitExceeded;
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    self.total_input = next_total;
                    self.stream_input += n;
                    if (self.expected_input_len) |expected| {
                        if (self.total_input > expected) return error.SizeMismatch;
                    }
                }
                if (self.plain.items.len == Codec.max_chunk_len or
                    ((self.finishing or self.flush_requested) and self.plain.items.len != 0))
                {
                    try self.writeChunk();
                    continue;
                }
                if (self.flush_requested) {
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (self.finishing) {
                    if (self.expected_input_len) |expected| {
                        if (self.total_input != expected) return error.SizeMismatch;
                    }
                    self.done = true;
                    self.stream_count += 1;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
        fn writeChunk(self: *Self) Error!void {
            std.debug.assert(self.plain.items.len != 0);
            try Codec.encodeChunk(&self.block_encoder, self.plain.items, &self.pending);
            self.plain.clearRetainingCapacity();
        }
    };
}
