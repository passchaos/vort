const std = @import("std");
const core = @import("../core.zig");
const Format = @import("incremental_decoder.zig").Format;

/// Build a bounded caller-output incremental encoder for Xerial or Hadoop
/// Snappy framing. Xerial publishes one complete raw Snappy block at a time;
/// Hadoop retains one encoded outer block until its uncompressed length is
/// known, then publishes the outer header and nested chunks together.
pub fn Encoder(comptime BlockEncoder: type, comptime Codec: type, comptime format: Format) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        block_encoder: BlockEncoder,
        plain: std.ArrayList(u8) = .empty,
        encoded: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        pending_ready: bool = false,
        xerial_header_written: bool = false,
        hadoop_block_input: usize = 0,
        flush_requested: bool = false,
        finishing: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        expected_input_len: ?usize = null,
        block_count: usize = 0,
        chunk_count: usize = 0,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = if (format == .xerial) struct {
            block_size: usize = 32 * 1024,
            max_input_len: usize = std.math.maxInt(usize),
            max_pending_output_len: usize = 64 * 1024 * 1024,
        } else struct {
            block_size: usize = 256 * 1024,
            chunk_size: usize = 64 * 1024,
            max_input_len: usize = std.math.maxInt(usize),
            max_pending_output_len: usize = 64 * 1024 * 1024,
        };
        pub const Snapshot = struct {
            input_read: usize,
            output_written: usize,
            buffered_input: usize,
            current_block_input: usize,
            staged_output: usize,
            pending_output: usize,
            block_count: usize,
            chunk_count: usize,
            finishing: bool,
            done: bool,
            retained_plain_capacity: usize,
            retained_encoded_capacity: usize,
            retained_pending_capacity: usize,
        };

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return initWithOptions(allocator, .{});
        }

        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Self {
            try validateOptions(options, null);
            return .{
                .allocator = allocator,
                .options = options,
                .block_encoder = try Codec.initBlockEncoder(allocator),
            };
        }

        pub fn initExactSize(allocator: std.mem.Allocator, options: Options, expected_input_len: usize) Error!Self {
            try validateOptions(options, expected_input_len);
            return .{
                .allocator = allocator,
                .options = options,
                .block_encoder = try Codec.initBlockEncoder(allocator),
                .expected_input_len = expected_input_len,
            };
        }

        pub fn deinit(self: *Self) void {
            self.block_encoder.deinit();
            self.plain.deinit(self.allocator);
            self.encoded.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }

        pub fn reset(self: *Self) void {
            self.resetState(self.options, self.expected_input_len);
        }

        pub fn resetWithOptions(self: *Self, options: Options) Error!void {
            try validateOptions(options, null);
            self.resetState(options, null);
        }

        pub fn resetExactSize(self: *Self, options: Options, expected_input_len: usize) Error!void {
            try validateOptions(options, expected_input_len);
            self.resetState(options, expected_input_len);
        }

        fn resetState(self: *Self, options: Options, expected_input_len: ?usize) void {
            const allocator = self.allocator;
            const block_encoder = self.block_encoder;
            var plain = self.plain;
            var encoded = self.encoded;
            var pending = self.pending;
            plain.clearRetainingCapacity();
            encoded.clearRetainingCapacity();
            pending.clearRetainingCapacity();
            self.* = .{
                .allocator = allocator,
                .options = options,
                .block_encoder = block_encoder,
                .plain = plain,
                .encoded = encoded,
                .pending = pending,
                .expected_input_len = expected_input_len,
            };
        }

        pub fn snapshot(self: *const Self) Snapshot {
            return .{
                .input_read = self.total_input,
                .output_written = self.total_output,
                .buffered_input = self.plain.items.len,
                .current_block_input = self.hadoop_block_input,
                .staged_output = self.pending.items.len,
                .pending_output = if (self.pending_ready) self.pending.items.len - self.pending_offset else 0,
                .block_count = self.block_count,
                .chunk_count = self.chunk_count,
                .finishing = self.finishing,
                .done = self.done,
                .retained_plain_capacity = self.plain.capacity,
                .retained_encoded_capacity = self.encoded.capacity,
                .retained_pending_capacity = self.pending.capacity,
            };
        }

        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }

        pub fn finish(self: *Self) void {
            if (!self.done) {
                self.finishing = true;
                self.flush_requested = false;
            }
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
                if (self.pending_ready) {
                    const remaining = self.pending.items[self.pending_offset..];
                    const count = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..count], remaining[0..count]);
                    self.pending_offset += count;
                    output_written += count;
                    self.total_output = std.math.add(usize, self.total_output, count) catch return error.IntegerOverflow;
                    if (self.pending_offset != self.pending.items.len)
                        return result(input_read, output_written, .need_output);
                    self.pending.clearRetainingCapacity();
                    self.pending_offset = 0;
                    self.pending_ready = false;
                    if (output_written == output.len and output.len != 0)
                        return result(input_read, output_written, .need_output);
                }

                if (comptime format == .xerial) {
                    if (!self.xerial_header_written) {
                        if (Codec.xerial_header.len > self.options.max_pending_output_len)
                            return error.OutputLimitExceeded;
                        try self.pending.appendSlice(self.allocator, &Codec.xerial_header);
                        self.xerial_header_written = true;
                        self.pending_ready = true;
                        continue;
                    }
                    try self.acceptXerialInput(input, &input_read);
                    if (self.plain.items.len == self.options.block_size or
                        ((self.finishing or self.flush_requested) and self.plain.items.len != 0))
                    {
                        try self.encodeXerialChunk();
                        continue;
                    }
                } else {
                    try self.acceptHadoopInput(input, &input_read);
                    if (self.plain.items.len == self.options.chunk_size or
                        self.hadoop_block_input == self.options.block_size or
                        ((self.finishing or self.flush_requested) and self.plain.items.len != 0))
                    {
                        try self.encodeHadoopChunk();
                    }
                    if (self.hadoop_block_input == self.options.block_size or
                        ((self.finishing or self.flush_requested) and self.hadoop_block_input != 0 and self.plain.items.len == 0))
                    {
                        try self.finishHadoopBlock();
                        continue;
                    }
                }

                if (self.flush_requested) {
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (self.finishing) {
                    if (self.expected_input_len) |expected| if (self.total_input != expected)
                        return error.SizeMismatch;
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn acceptXerialInput(self: *Self, input: []const u8, input_read: *usize) Error!void {
            const room = self.options.block_size - self.plain.items.len;
            try self.acceptInput(input, input_read, room);
        }

        fn acceptHadoopInput(self: *Self, input: []const u8, input_read: *usize) Error!void {
            const chunk_room = self.options.chunk_size - self.plain.items.len;
            const block_room = self.options.block_size - self.hadoop_block_input;
            try self.acceptInput(input, input_read, @min(chunk_room, block_room));
        }

        fn acceptInput(self: *Self, input: []const u8, input_read: *usize, room: usize) Error!void {
            const count = @min(room, input.len - input_read.*);
            if (count == 0) return;
            const next_total = std.math.add(usize, self.total_input, count) catch return error.IntegerOverflow;
            if (next_total > self.options.max_input_len) return error.OutputLimitExceeded;
            if (self.expected_input_len) |expected| if (next_total > expected)
                return error.SizeMismatch;
            try self.plain.appendSlice(self.allocator, input[input_read.*..][0..count]);
            input_read.* += count;
            self.total_input = next_total;
            if (comptime format == .hadoop)
                self.hadoop_block_input = std.math.add(usize, self.hadoop_block_input, count) catch return error.IntegerOverflow;
        }

        fn encodeXerialChunk(self: *Self) Error!void {
            std.debug.assert(self.plain.items.len != 0 and self.pending.items.len == 0);
            try self.encodePlain();
            const pending_len = std.math.add(usize, 4, self.encoded.items.len) catch return error.IntegerOverflow;
            if (pending_len > self.options.max_pending_output_len) return error.OutputLimitExceeded;
            const start = self.pending.items.len;
            errdefer self.pending.items.len = start;
            try appendBe32(self.allocator, &self.pending, std.math.cast(u32, self.encoded.items.len) orelse return error.IntegerOverflow);
            try self.pending.appendSlice(self.allocator, self.encoded.items);
            self.plain.clearRetainingCapacity();
            self.chunk_count = std.math.add(usize, self.chunk_count, 1) catch return error.IntegerOverflow;
            self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
            self.pending_ready = true;
        }

        fn encodeHadoopChunk(self: *Self) Error!void {
            std.debug.assert(self.plain.items.len != 0 and !self.pending_ready);
            try self.encodePlain();
            const placeholder = @as(usize, @intFromBool(self.pending.items.len == 0)) * 4;
            const growth = std.math.add(usize, placeholder + 4, self.encoded.items.len) catch return error.IntegerOverflow;
            const pending_len = std.math.add(usize, self.pending.items.len, growth) catch return error.IntegerOverflow;
            if (pending_len > self.options.max_pending_output_len) return error.OutputLimitExceeded;
            const start = self.pending.items.len;
            errdefer self.pending.items.len = start;
            if (placeholder != 0) try self.pending.appendNTimes(self.allocator, 0, 4);
            try appendBe32(self.allocator, &self.pending, std.math.cast(u32, self.encoded.items.len) orelse return error.IntegerOverflow);
            try self.pending.appendSlice(self.allocator, self.encoded.items);
            self.plain.clearRetainingCapacity();
            self.chunk_count = std.math.add(usize, self.chunk_count, 1) catch return error.IntegerOverflow;
        }

        fn finishHadoopBlock(self: *Self) Error!void {
            std.debug.assert(self.hadoop_block_input != 0 and self.pending.items.len >= 8 and !self.pending_ready);
            const block_len = std.math.cast(u32, self.hadoop_block_input) orelse return error.IntegerOverflow;
            std.mem.writeInt(u32, self.pending.items[0..4], block_len, .big);
            self.hadoop_block_input = 0;
            self.block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
            self.pending_ready = true;
        }

        fn encodePlain(self: *Self) Error!void {
            self.encoded.clearRetainingCapacity();
            try Codec.encodeBlock(&self.block_encoder, self.plain.items, &self.encoded);
        }

        fn validateOptions(options: Options, expected_input_len: ?usize) Error!void {
            if (options.block_size == 0 or options.block_size > std.math.maxInt(u32) or
                options.max_pending_output_len == 0)
                return error.InvalidBlockPlan;
            if (comptime format == .hadoop) {
                if (options.chunk_size == 0 or options.chunk_size > std.math.maxInt(u32))
                    return error.InvalidBlockPlan;
            }
            if (expected_input_len) |expected| if (expected > options.max_input_len)
                return error.OutputLimitExceeded;
        }

        fn appendBe32(allocator: std.mem.Allocator, output: *std.ArrayList(u8), value: u32) Error!void {
            var bytes: [4]u8 = undefined;
            std.mem.writeInt(u32, &bytes, value, .big);
            try output.appendSlice(allocator, &bytes);
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
    };
}
