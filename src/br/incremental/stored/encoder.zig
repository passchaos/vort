const std = @import("std");
const core = @import("../../../core.zig");
const memory = @import("allocator_adapter.zig");
const PendingCheckpoint = @import("pending_checkpoint.zig").Checkpoint;
const step_borrows = @import("step_borrows.zig");

/// Build an incremental encoder for Brotli stored/uncompressed streams. Input
/// is bounded to one format meta-block, while encoded bytes are drained through
/// arbitrary caller output without rebuilding previous blocks.
pub fn Encoder(comptime Codec: type) type {
    return struct {
        allocator: std.mem.Allocator,
        options: Options,
        memory_binding: memory.Binding = .{},
        codec_state: Codec.State = .{},
        plain: std.ArrayList(u8) = .empty,
        pending: std.ArrayList(u8) = .empty,
        pending_offset: usize = 0,
        pending_metadata: []const u8 = &.{},
        metadata_requested: bool = false,
        metadata_stream: ?MetadataStream = null,
        prefix_written: bool = false,
        flush_requested: bool = false,
        seal_flush_tail: bool = false,
        finishing: bool = false,
        final_written: bool = false,
        done: bool = false,
        total_input: Counter = 0,
        total_output: Counter = 0,
        stream_input: Counter = 0,
        stream_output: Counter = 0,
        stream_count: Counter = 0,

        const Self = @This();
        /// Byte counts span complete streams, independently of address space.
        /// Keep the established public type on targets with 64-bit `usize`.
        pub const Counter = core.StreamCount;
        pub const Error = Codec.Error || memory.Error || error{ InvalidStreamState, SizeMismatch };
        const MetadataStream = struct {
            remaining: usize,
            header_written: bool = false,
        };
        pub const Options = struct {
            stream: Codec.StreamOptions = .{},
            max_input_len: Counter = std.math.maxInt(Counter),
            block_len: usize = if (@hasDecl(Codec, "default_block_len")) Codec.default_block_len else 64 * 1024,
        };
        pub const Snapshot = struct {
            /// Cumulative source bytes accepted across all continued streams.
            input_read: Counter,
            /// Cumulative encoded bytes returned across all continued streams.
            output_written: Counter,
            /// Source bytes accepted for the current stream.
            stream_input: Counter,
            /// Encoded bytes returned for the current stream.
            stream_output: Counter,
            buffered_input: usize,
            pending_output: usize,
            stream_count: Counter,
            stream_index: Counter,
            metadata_pending: bool,
            /// The body still to be supplied for an active streamed request;
            /// the original borrowed length for a legacy metadata request.
            metadata_bytes: usize,
            metadata_streaming: bool = false,
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
        /// Internal composition surface for complete-frame operations whose
        /// sibling encoders and retained wires share one total-memory policy.
        pub fn initWithSharedLease(allocator: std.mem.Allocator, options: Options, lease: @import("../../encoder/total_budget.zig").Lease) Error!Self {
            _ = try resolveBlockLen(options);
            return .{ .allocator = allocator, .options = options, .memory_binding = try memory.Binding.initShared(allocator, lease) };
        }
        pub fn deinit(self: *Self) void {
            const allocator = self.memory_binding.current(self.allocator);
            if (@hasDecl(Codec, "deinitState")) Codec.deinitState(&self.codec_state, allocator);
            self.plain.deinit(allocator);
            self.pending.deinit(allocator);
            self.memory_binding.deinit();
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
            self.metadata_stream = null;
            self.prefix_written = false;
            self.flush_requested = false;
            self.seal_flush_tail = false;
            self.finishing = false;
            self.final_written = false;
            self.done = false;
            self.total_input = 0;
            self.total_output = 0;
        }
        pub fn nextStream(self: *Self, options: Options) Error!void {
            if (!self.done or self.pending_offset != self.pending.items.len) return error.InvalidBlockPlan;
            _ = try resolveBlockLen(options);
            try step_borrows.validateNextStream(self, options);
            _ = self.memory_binding.activate(Codec, self.allocator, &self.codec_state, options.stream, self.plain.capacity, self.pending.capacity) catch |err|
                return @errorCast(self.memory_binding.mapError(err));
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
                .metadata_pending = self.metadata_requested or self.metadata_stream != null,
                .metadata_bytes = if (self.metadata_stream) |active| active.remaining else if (self.metadata_requested) self.pending_metadata.len else 0,
                .metadata_streaming = self.metadata_stream != null,
                .flush_requested = self.flush_requested,
                .finishing = self.finishing,
                .done = self.done,
            };
        }
        pub fn memorySnapshot(self: *const Self) @import("../../encoder/total_budget.zig").Snapshot {
            return self.memory_binding.snapshot();
        }

        pub fn retainedCapacity(self: *const Self) usize {
            const maximum = std.math.maxInt(usize);
            var retained = std.math.add(usize, self.plain.capacity, self.pending.capacity) catch return maximum;
            if (@hasDecl(Codec, "stateRetainedCapacity")) {
                retained = std.math.add(usize, retained, Codec.stateRetainedCapacity(&self.codec_state)) catch return maximum;
            }
            if (!self.memory_binding.shared) {
                if (self.memory_binding.lease) |lease| {
                    const budget = lease.snapshot();
                    if (budget.available)
                        retained = std.math.add(usize, retained, budget.control_bytes) catch return maximum;
                }
            }
            return retained;
        }
        pub fn finish(self: *Self) Error!void {
            if (self.metadata_stream != null) return error.InvalidStreamState;
            self.finishing = true;
            // Accepted metadata follows any buffered plaintext before the
            // final marker. A plain flush alone still uses the final block.
            self.flush_requested = self.metadata_requested;
            self.seal_flush_tail = false;
        }
        /// Publish all accepted plaintext without ending the stream. After
        /// `step` acknowledges the flush with `need_input`, a decoder can
        /// reproduce that plaintext without waiting for a later input chunk.
        pub fn flush(self: *Self) void {
            if (self.finishing or self.done) return;
            self.flush_requested = true;
            self.seal_flush_tail = true;
        }
        /// Internal complete-wire chunk boundary: preserve block segmentation
        /// without requiring the unfinished prefix to be independently decodable.
        pub fn endChunk(self: *Self) void {
            if (!self.finishing and !self.done) self.flush_requested = true;
        }
        /// Insert a metadata meta-block after all previously accepted content.
        /// The caller must keep `metadata` alive until the encoder returns
        /// `need_input`, or `done` when finish follows this request; content can
        /// otherwise continue in the same Brotli stream.
        pub fn writeMetadata(self: *Self, metadata: []const u8) Error!void {
            if (self.finishing or self.done or self.metadata_requested or self.metadata_stream != null) return error.InvalidBlockPlan;
            if (@hasDecl(Codec, "validateMetadata")) try Codec.validateMetadata(metadata.len);
            try step_borrows.validateMetadata(self, metadata);
            self.pending_metadata = metadata;
            self.metadata_requested = true;
            self.flush_requested = true;
        }

        /// Reserve one metadata block after the accepted plaintext. No body
        /// is borrowed or allocated here. Drive it through `stepMetadata`.
        pub fn beginMetadata(self: *Self, len: usize) Error!void {
            if (comptime !@hasDecl(Codec, "writeMetadataHeader")) return error.InvalidStreamState;
            if (self.finishing or self.done or self.metadata_requested or self.metadata_stream != null)
                return error.InvalidStreamState;
            try Codec.validateMetadata(len);
            self.metadata_stream = .{ .remaining = len };
            self.flush_requested = true;
        }

        /// Drain preceding wire and the metadata header, then copy body bytes
        /// directly from input to output. Only the consumed body prefix counts
        /// in `progress.input_read`; no offered slice survives the call.
        /// The request completes when `metadata_pending` clears, including a
        /// zero-length request. Plaintext steps and finish can then resume.
        pub fn stepMetadata(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (comptime !@hasDecl(Codec, "writeMetadataHeader")) return error.InvalidStreamState;
            const active = self.metadata_stream orelse return error.InvalidStreamState;
            if (input.len > active.remaining) return error.SizeMismatch;
            return self.stepInner(input, output, true) catch |err|
                return @errorCast(self.memory_binding.mapError(err));
        }

        pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            if (self.metadata_stream != null) return error.InvalidStreamState;
            return self.stepInner(input, output, false) catch |err|
                return @errorCast(self.memory_binding.mapError(err));
        }

        fn stepInner(self: *Self, input: []const u8, output: []u8, comptime metadata_input: bool) Error!core.StepResult {
            const plaintext: []const u8 = if (metadata_input) &.{} else input;
            const block_len = try resolveBlockLen(self.options);
            if (self.plain.items.len > block_len) return error.InvalidBlockPlan;
            if (self.done) {
                if (input.len != 0) return error.TrailingData;
                return .{ .status = .done };
            }
            try step_borrows.validate(self, input, output);
            if (!metadata_input) {
                if ((self.finishing or self.flush_requested) and plaintext.len != 0) return error.TrailingData;
                // Validate the whole offer before draining prefix/pending
                // output so backpressure cannot conceal an input-limit error.
                const offered_total = std.math.add(Counter, self.total_input, @as(Counter, plaintext.len)) catch return error.IntegerOverflow;
                if (offered_total > self.options.max_input_len) return error.OutputLimitExceeded;
                _ = std.math.add(Counter, self.stream_input, @as(Counter, plaintext.len)) catch return error.IntegerOverflow;
            }
            const allocator = try self.memory_binding.activate(Codec, self.allocator, &self.codec_state, self.options.stream, self.plain.capacity, self.pending.capacity);
            var input_read: usize = 0;
            var output_written: usize = 0;
            while (true) {
                const ready_end = Codec.readyOutputLen(&self.codec_state, self.pending.items.len, self.final_written);
                if (comptime !metadata_input and @hasDecl(Codec, "byte_aligned_flush") and Codec.byte_aligned_flush) {
                    if (self.seal_flush_tail and !self.metadata_requested and self.plain.items.len == 0 and ready_end != self.pending.items.len) {
                        // An empty metadata block seals the mutable tail without
                        // ending the stream or changing its plaintext history.
                        // Do it before exposing more pending bytes in this step.
                        try self.writeMetadataBlock(allocator, "");
                        continue;
                    }
                }
                if (self.pending_offset != ready_end) {
                    const remaining = self.pending.items[self.pending_offset..ready_end];
                    const n = @min(output.len - output_written, remaining.len);
                    const total = std.math.add(Counter, self.total_output, @as(Counter, n)) catch return error.IntegerOverflow;
                    const cumulative = std.math.add(Counter, self.stream_output, @as(Counter, n)) catch return error.IntegerOverflow;
                    @memcpy(output[output_written..][0..n], remaining[0..n]);
                    self.pending_offset += n;
                    output_written += n;
                    self.total_output = total;
                    self.stream_output = cumulative;
                    if (self.pending_offset != ready_end) return result(input_read, output_written, .need_output);
                    if (ready_end == self.pending.items.len) {
                        self.pending.clearRetainingCapacity();
                        self.pending_offset = 0;
                    }
                    // Return all published progress before the streamed path
                    // can attempt another header/block allocation or body copy.
                    if (metadata_input and output_written != 0)
                        return result(0, output_written, .need_output);
                    if (output_written == output.len and output.len != 0) return result(input_read, output_written, .need_output);
                }
                if (metadata_input and self.metadata_stream.?.header_written) {
                    std.debug.assert(self.pending.items.len == 0);
                    return self.copyMetadataBody(input, output);
                }
                if (!self.prefix_written) {
                    try self.writePrefix(allocator, block_len);
                    self.prefix_written = true;
                    continue;
                }
                const room = block_len - self.plain.items.len;
                const n = @min(room, plaintext.len - input_read);
                if (n != 0) {
                    const total = std.math.add(Counter, self.total_input, @as(Counter, n)) catch return error.IntegerOverflow;
                    const cumulative = std.math.add(Counter, self.stream_input, @as(Counter, n)) catch return error.IntegerOverflow;
                    try self.plain.appendSlice(allocator, plaintext[input_read..][0..n]);
                    input_read += n;
                    self.total_input = total;
                    self.stream_input = cumulative;
                }
                // A codec can retain an exact full block until more input or
                // finish determines whether its meta-block header is final.
                const defer_full_block = if (@hasDecl(Codec, "deferFullBlock"))
                    Codec.deferFullBlock(self.options.stream)
                else if (@hasDecl(Codec, "defer_full_block_until_more_input"))
                    Codec.defer_full_block_until_more_input
                else
                    false;
                const full_block_ready = self.plain.items.len == block_len and
                    (!defer_full_block or self.finishing or self.flush_requested or
                        input_read != plaintext.len);
                if (full_block_ready or
                    ((self.finishing or self.flush_requested) and self.plain.items.len != 0))
                {
                    if (self.finishing and !self.metadata_requested) {
                        if (comptime @hasDecl(Codec, "writeFinalBlock")) {
                            try self.writeFinalBlock(allocator);
                            self.plain.clearRetainingCapacity();
                            self.final_written = true;
                            continue;
                        }
                    }
                    try self.writeBlock(allocator);
                    continue;
                }
                if (metadata_input) {
                    try self.writeStreamedMetadataHeader(allocator);
                    continue;
                }
                if (self.flush_requested) {
                    if (self.metadata_requested) {
                        try self.writeMetadataBlock(allocator, self.pending_metadata);
                        self.pending_metadata = &.{};
                        self.metadata_requested = false;
                        continue;
                    }
                    self.flush_requested = false;
                    self.seal_flush_tail = false;
                    if (!self.finishing) return result(input_read, output_written, .need_input);
                }
                if (self.finishing and !self.final_written) {
                    try self.writeFinal(allocator);
                    self.final_written = true;
                    continue;
                }
                if (self.finishing) {
                    self.stream_count = try core.stream_count.addLocal(self.stream_count, 1);
                    self.done = true;
                    return result(input_read, output_written, .done);
                }
                return result(input_read, output_written, .need_input);
            }
        }

        fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
            return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
        }
        fn resolveBlockLen(options: Options) Error!usize {
            if (@hasDecl(Codec, "validateStreamOptions")) try Codec.validateStreamOptions(options.stream);
            const block_len = if (@hasDecl(Codec, "resolveBlockLen"))
                try Codec.resolveBlockLen(options.stream, options.block_len)
            else
                options.block_len;
            if (block_len == 0 or block_len > Codec.max_block_len) return error.InvalidBlockPlan;
            return block_len;
        }

        fn writePrefix(self: *Self, allocator: std.mem.Allocator, block_len: usize) Error!void {
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            if (@hasDecl(Codec, "writePrefixWithBlockLen")) {
                try Codec.writePrefixWithBlockLen(allocator, &self.pending, &self.codec_state, self.options.stream, block_len);
            } else {
                try Codec.writePrefix(allocator, &self.pending, &self.codec_state, self.options.stream);
            }
        }

        fn writeMetadataBlock(self: *Self, allocator: std.mem.Allocator, body: []const u8) Error!void {
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            try Codec.writeMetadata(allocator, &self.pending, &self.codec_state, body);
        }

        fn writeStreamedMetadataHeader(self: *Self, allocator: std.mem.Allocator) Error!void {
            const active = &self.metadata_stream.?;
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            try Codec.writeMetadataHeader(allocator, &self.pending, &self.codec_state, active.remaining);
            active.header_written = true;
        }

        fn copyMetadataBody(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
            const active = &self.metadata_stream.?;
            const n = @min(input.len, output.len);
            const total = std.math.add(Counter, self.total_output, @as(Counter, n)) catch return error.IntegerOverflow;
            const cumulative = std.math.add(Counter, self.stream_output, @as(Counter, n)) catch return error.IntegerOverflow;
            @memcpy(output[0..n], input[0..n]);
            self.total_output = total;
            self.stream_output = cumulative;
            active.remaining -= n;
            if (active.remaining == 0) {
                self.metadata_stream = null;
                self.flush_requested = false;
                self.seal_flush_tail = false;
            }
            return result(n, n, if (n != input.len) .need_output else .need_input);
        }

        fn writeFinal(self: *Self, allocator: std.mem.Allocator) Error!void {
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            try Codec.writeFinal(allocator, &self.pending, &self.codec_state);
        }

        fn writeFinalBlock(self: *Self, allocator: std.mem.Allocator) Error!void {
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            try Codec.writeFinalBlock(allocator, &self.pending, &self.codec_state, self.plain.items);
        }

        fn writeBlock(self: *Self, allocator: std.mem.Allocator) Error!void {
            const checkpoint = PendingCheckpoint.init(&self.pending);
            errdefer checkpoint.restore(&self.pending);
            std.debug.assert(self.plain.items.len != 0);
            try Codec.writeBlock(allocator, &self.pending, &self.codec_state, self.plain.items);
            self.plain.clearRetainingCapacity();
        }
    };
}

test {
    _ = @import("lifecycle_borrows_tests.zig");
    _ = @import("finish_metadata_tests.zig");
    _ = @import("metadata_stream_tests.zig");
    _ = @import("step_borrows_tests.zig");
    _ = @import("encoder_tests.zig");
    _ = @import("encoder_counter_tests.zig");
    _ = @import("encoder_block_options_tests.zig");
    _ = @import("encoder_memory_tests.zig");
    _ = @import("stored_resource_tests.zig");
}
