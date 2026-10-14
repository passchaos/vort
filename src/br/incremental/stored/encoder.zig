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
        pending_metadata: []const u8 = &.{},
        metadata_requested: bool = false,
        prefix_written: bool = false,
        flush_requested: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: usize = 0,
        total_output: usize = 0,
        stream_input: usize = 0,
        stream_output: usize = 0,
        stream_count: usize = 0,

        const Self = @This();
        pub const Error = Codec.Error;
        pub const Options = struct {
            stream: Codec.StreamOptions = .{},
            max_input_len: usize = std.math.maxInt(usize),
            block_len: usize = if (@hasDecl(Codec, "default_block_len")) Codec.default_block_len else 64 * 1024,
        };
        pub const Snapshot = struct {
            /// Cumulative source bytes accepted across all continued streams.
            input_read: usize,
            /// Cumulative encoded bytes returned across all continued streams.
            output_written: usize,
            /// Source bytes accepted for the current stream.
            stream_input: usize,
            /// Encoded bytes returned for the current stream.
            stream_output: usize,
            buffered_input: usize,
            pending_output: usize,
            stream_count: usize,
            stream_index: usize,
            metadata_pending: bool,
            metadata_bytes: usize,
            flush_requested: bool,
            finishing: bool,
            done: bool,
        };

        pub fn init(allocator: std.mem.Allocator) Self {
            return initWithOptions(allocator, .{});
        }
        pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Self {
            return .{ .allocator = allocator, .options = options };
        }
        pub fn deinit(self: *Self) void {
            if (@hasDecl(Codec, "deinitState")) Codec.deinitState(&self.codec_state, self.allocator);
            self.plain.deinit(self.allocator);
            self.pending.deinit(self.allocator);
            self.* = undefined;
        }
        pub fn reset(self: *Self) void {
            self.stream_input = 0;
            self.stream_output = 0;
            self.stream_count = 0;
            self.resetStream(self.options);
        }
        fn resetStream(self: *Self, options: Options) void {
            self.options = options;
            self.plain.clearRetainingCapacity();
            self.pending.clearRetainingCapacity();
            if (@hasDecl(Codec, "resetState")) {
                Codec.resetState(&self.codec_state);
            } else self.codec_state = .{};
            self.pending_offset = 0;
            self.pending_metadata = &.{};
            self.metadata_requested = false;
            self.prefix_written = false;
            self.flush_requested = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
        }
        pub fn nextStream(self: *Self, options: Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            self.resetStream(options);
        }
        pub fn snapshot(self: *const Self) Snapshot {
            const ready_end = Codec.readyOutputLen(&self.codec_state, self.pending.items.len, self.final_written);
            return .{
                .input_read = self.stream_input,
                .output_written = self.stream_output,
                .stream_input = self.total_input,
                .stream_output = self.total_output,
                .buffered_input = self.plain.items.len,
                // Exclude the mutable bit-reservoir tail: the encoder owns it
                // until a later header or the final marker completes the byte.
                .pending_output = ready_end - self.pending_offset,
                .stream_count = self.stream_count,
                .stream_index = if (self.done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
                .metadata_pending = self.metadata_requested,
                .metadata_bytes = if (self.metadata_requested) self.pending_metadata.len else 0,
                .flush_requested = self.flush_requested,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn retainedCapacity(self: *const Self) usize {
            var total = self.plain.capacity + self.pending.capacity;
            if (@hasDecl(Codec, "stateRetainedCapacity")) total += Codec.stateRetainedCapacity(&self.codec_state);
            return total;
        }
        pub fn finish(self: *Self) Error!void {
            self.finishing = true;
            self.flush_requested = false;
        }
        /// Publish buffered bytes as a non-final uncompressed meta-block. The
        /// bit-level writer state is retained so later input continues the same
        /// Brotli stream after `step` acknowledges the flush with `need_input`.
        pub fn flush(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }
        /// Insert a metadata meta-block after all previously accepted content.
        /// The caller must keep `metadata` alive until the encoder returns
        /// `need_input`; content can then continue in the same Brotli stream.
        pub fn writeMetadata(self: *Self, metadata: []const u8) Error!void {
            if (self.finishing or self.done or self.metadata_requested) return error.InvalidBlockPlan;
            self.pending_metadata = metadata;
            self.metadata_requested = true;
            self.flush_requested = true;
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            const block_len = if (@hasDecl(Codec, "resolveBlockLen"))
                try Codec.resolveBlockLen(self.options.stream, self.options.block_len)
            else
                self.options.block_len;
            if (block_len == 0 or block_len > Codec.max_block_len or
                self.plain.items.len > block_len) return error.InvalidBlockPlan;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            if ((self.finishing or self.flush_requested) and input.len != 0) return error.TrailingData;
            // Validate the whole offered slice before draining prefix/pending
            // output. Otherwise an empty output buffer can hide a deterministic
            // input-limit error behind `need_output`, making error behavior
            // depend on caller output chunking.
            const offered_total = std.math.add(usize, self.total_input, input.len) catch return error.IntegerOverflow;
            if (offered_total > self.options.max_input_len) return error.OutputLimitExceeded;
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                const ready_end = Codec.readyOutputLen(&self.codec_state, self.pending.items.len, self.final_written);
                if (self.pending_offset != ready_end) {
                    const remaining = self.pending.items[self.pending_offset..ready_end];
                    const n = @min(output.len - output_written, remaining.len);
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output += n;
                    self.stream_output += n;
                    if (self.pending_offset != ready_end) return result(input_read, output_written, .need_output);
                    if (ready_end == self.pending.items.len) {
                        self.pending.clearRetainingCapacity();
                        self.pending_offset = 0;
                    }
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (!self.prefix_written) {
                    try Codec.writePrefix(self.allocator, &self.pending, &self.codec_state, self.options.stream);
                    self.prefix_written = true;
                    continue;
                }
                const room = block_len - self.plain.items.len;
                const n = @min(room, input.len - input_read);
                if (n != 0) {
                    const total = std.math.add(usize, self.total_input, n) catch return error.IntegerOverflow;
                    try self.plain.appendSlice(self.allocator, input[input_read..][0..n]);
                    input_read += n;
                    self.total_input = total;
                    self.stream_input += n;
                }
                if (self.plain.items.len == block_len or
                    ((self.finishing or self.flush_requested) and self.plain.items.len != 0))
                {
                    try self.writeBlock();
                    continue;
                }
                if (self.flush_requested) {
                    if (self.metadata_requested) {
                        try Codec.writeMetadata(self.allocator, &self.pending, &self.codec_state, self.pending_metadata);
                        self.pending_metadata = &.{};
                        self.metadata_requested = false;
                        continue;
                    }
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (self.finishing and !self.final_written) {
                    try Codec.writeFinal(self.allocator, &self.pending, &self.codec_state);
                    self.final_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.stream_count += 1;
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
        fn writeBlock(self: *Self) Error!void {
            std.debug.assert(self.plain.items.len != 0);
            try Codec.writeBlock(self.allocator, &self.pending, &self.codec_state, self.plain.items);
            self.plain.clearRetainingCapacity();
        }
    };
}
