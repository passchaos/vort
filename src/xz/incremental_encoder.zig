const std = @import("std");
const core = @import("../core.zig");
const writer = @import("writer.zig");
const parallel_types = @import("incremental_parallel/types.zig");
const parallel_owner = @import("incremental_parallel/owner.zig");

/// Block-bounded XZ/LZMA2 encoder. Complete blocks are serialized through the
/// same helpers as one-shot writing, while plaintext and pending output remain
/// explicitly bounded by caller-selected options.
pub const Encoder = struct {
    allocator: std.mem.Allocator,
    options: Options,
    plain: std.ArrayList(u8) = .empty,
    pending: std.ArrayList(u8) = .empty,
    pending_offset: usize = 0,
    records: std.ArrayList(writer.BlockRecord) = .empty,
    header_written: bool = false,
    footer_written: bool = false,
    flush_requested: bool = false,
    finishing: bool = false,
    done: bool = false,
    expected_input_len: ?usize = null,
    current_input: usize = 0,
    current_output: usize = 0,
    total_input: usize = 0,
    total_output: usize = 0,
    block_count: usize = 0,
    stream_count: usize = 0,
    parallel_state: ?*parallel_owner.Owner = null,

    pub const Error = writer.Error || std.mem.Allocator.Error;
    pub const ParallelSnapshot = parallel_types.Snapshot;
    pub const Options = struct {
        check: writer.Check = .crc64,
        block_size: usize = 1024 * 1024,
        dictionary_size: usize = 4096,
        chunk_size: usize = 65536,
        parser: writer.Parser = .greedy,
        properties: writer.Properties = .{},
        match_options: ?writer.MatchOptions = null,
        filters: []const writer.Filter = &.{},
        /// Declare exact packed and unpacked sizes in every complete Block
        /// Header, using the same block writer as the one-shot APIs.
        include_block_sizes: bool = false,
        /// Explicit persistent Block workers. Caller I/O, filters, allocator
        /// and profile storage must remain valid until all workers join.
        parallel: ?parallel_types.Options = null,
        payload_encoding: writer.PayloadEncoding = .compressed,
        max_input_len: usize = std.math.maxInt(usize),
        max_pending_output_len: usize = 16 * 1024 * 1024,
        max_block_count: usize = 1024 * 1024,

        pub fn fromPreset(level: u32, extreme: bool) Error!Options {
            const preset = try writer.EncodeOptions.fromPreset(level, extreme);
            return .{ .dictionary_size = preset.dictionary_size, .chunk_size = preset.chunk_size, .parser = preset.parser, .properties = preset.properties, .match_options = preset.match_options };
        }
        pub fn validate(self: Options) Error!void {
            try validateOptions(self);
        }
        pub fn recordEffectiveSettings(self: Options) void {
            if (self.match_options) |options| options.recordEffectiveSettings();
        }
        pub fn writerOptions(self: Options) writer.EncodeOptions {
            return .{
                .check = self.check,
                .block_size = self.block_size,
                .dictionary_size = self.dictionary_size,
                .chunk_size = self.chunk_size,
                .parser = self.parser,
                .properties = self.properties,
                .match_options = self.match_options,
                .filters = self.filters,
                .include_block_sizes = self.include_block_sizes,
            };
        }
    };
    pub const Snapshot = struct {
        input_read: usize,
        output_written: usize,
        current_input: usize,
        current_output: usize,
        buffered_input: usize,
        pending_output: usize,
        current_stream_blocks: usize,
        block_count: usize,
        stream_count: usize,
        stream_index: usize,
        flush_requested: bool,
        finishing: bool,
        done: bool,
        retained_input_capacity: usize,
        retained_output_capacity: usize,
        retained_record_capacity: usize,
        parallel: ParallelSnapshot = .{},
    };

    pub fn init(allocator: std.mem.Allocator) Error!Encoder {
        return initWithOptions(allocator, .{});
    }

    pub fn initWithOptions(allocator: std.mem.Allocator, options: Options) Error!Encoder {
        return initConfigured(allocator, options, null);
    }

    fn initConfigured(allocator: std.mem.Allocator, options: Options, expected_input_len: ?usize) Error!Encoder {
        try validateOptions(options);
        var state: Encoder = .{ .allocator = allocator, .options = options, .expected_input_len = expected_input_len };
        if (options.parallel != null)
            state.parallel_state = try parallel_owner.Owner.create(allocator, try parallelConfig(options, expected_input_len), .{}, .{});
        options.recordEffectiveSettings();
        if (state.parallel_state) |owner| owner.publishProfiles();
        return state;
    }

    pub fn initExactSize(
        allocator: std.mem.Allocator,
        options: Options,
        expected_input_len: usize,
    ) Error!Encoder {
        return initConfigured(allocator, options, expected_input_len);
    }

    pub fn deinit(self: *Encoder) void {
        if (self.parallel_state) |owner| {
            owner.deinit();
            self.* = undefined;
            return;
        }
        self.plain.deinit(self.allocator);
        self.pending.deinit(self.allocator);
        self.records.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn reset(self: *Encoder) void {
        if (self.parallel_state) |owner| {
            owner.reset(self.expected_input_len);
            self.syncParallelState();
            return;
        }
        self.total_input = 0;
        self.total_output = 0;
        self.block_count = 0;
        self.stream_count = 0;
        self.resetStream(self.options, self.expected_input_len);
    }

    pub fn nextStream(self: *Encoder, options: Options) Error!void {
        try self.nextConfiguredStream(options, null);
    }

    pub fn nextStreamExactSize(
        self: *Encoder,
        options: Options,
        expected_input_len: usize,
    ) Error!void {
        try self.nextConfiguredStream(options, expected_input_len);
    }

    fn nextConfiguredStream(self: *Encoder, options: Options, expected_input_len: ?usize) Error!void {
        if (!self.done or self.pending_offset != self.pending.items.len)
            return error.InvalidBlockPlan;
        try validateOptions(options);
        if (self.parallel_state) |owner| {
            if (options.parallel != null) {
                try owner.nextStream(try parallelConfig(options, expected_input_len));
                self.options = options;
                self.expected_input_len = expected_input_len;
                self.syncParallelState();
                return;
            }
            const released = try owner.releaseToSerial();
            self.parallel_state = null;
            self.plain = released.storage.plain;
            self.pending = released.storage.pending;
            self.records = released.storage.records;
            self.total_input = released.counters.total_input;
            self.total_output = released.counters.total_output;
            self.block_count = released.counters.block_count;
            self.stream_count = released.counters.stream_count;
            self.resetStream(options, expected_input_len);
            return;
        }
        if (options.parallel != null) {
            const owner = try parallel_owner.Owner.create(self.allocator, try parallelConfig(options, expected_input_len), .{
                .plain = self.plain,
                .pending = self.pending,
                .records = self.records,
            }, .{
                .total_input = self.total_input,
                .total_output = self.total_output,
                .block_count = self.block_count,
                .stream_count = self.stream_count,
            });
            // Publication cannot fail: the old descriptors remain owned by
            // this value until the complete new authority has been created.
            self.plain = .empty;
            self.pending = .empty;
            self.pending_offset = 0;
            self.records = .empty;
            self.parallel_state = owner;
            self.options = options;
            self.expected_input_len = expected_input_len;
            self.syncParallelState();
            return;
        }
        self.resetStream(options, expected_input_len);
    }

    fn resetStream(self: *Encoder, options: Options, expected_input_len: ?usize) void {
        self.options = options;
        options.recordEffectiveSettings();
        self.plain.clearRetainingCapacity();
        self.pending.clearRetainingCapacity();
        self.pending_offset = 0;
        self.records.clearRetainingCapacity();
        self.header_written = false;
        self.footer_written = false;
        self.flush_requested = false;
        self.finishing = false;
        self.done = false;
        self.expected_input_len = expected_input_len;
        self.current_input = 0;
        self.current_output = 0;
    }

    pub fn snapshot(self: *const Encoder) Snapshot {
        if (self.parallel_state) |owner| {
            const observed = owner.snapshot();
            return .{
                .input_read = observed.counters.total_input,
                .output_written = observed.counters.total_output,
                .current_input = observed.current_input,
                .current_output = observed.current_output,
                .buffered_input = observed.buffered_input,
                .pending_output = observed.pending_output,
                .current_stream_blocks = observed.current_stream_blocks,
                .block_count = observed.counters.block_count,
                .stream_count = observed.counters.stream_count,
                .stream_index = observed.stream_index,
                .flush_requested = observed.flush_requested,
                .finishing = observed.finishing,
                .done = observed.done,
                .retained_input_capacity = observed.retained_input_capacity,
                .retained_output_capacity = observed.retained_output_capacity,
                .retained_record_capacity = observed.retained_record_capacity,
                .parallel = observed.parallel,
            };
        }
        return .{
            .input_read = self.total_input,
            .output_written = self.total_output,
            .current_input = self.current_input,
            .current_output = self.current_output,
            .buffered_input = self.plain.items.len,
            .pending_output = self.pending.items.len - self.pending_offset,
            .current_stream_blocks = self.records.items.len,
            .block_count = self.block_count,
            .stream_count = self.stream_count,
            .stream_index = if (self.done and self.stream_count != 0) self.stream_count - 1 else self.stream_count,
            .flush_requested = self.flush_requested,
            .finishing = self.finishing,
            .done = self.done,
            .retained_input_capacity = self.plain.capacity,
            .retained_output_capacity = self.pending.capacity,
            .retained_record_capacity = self.records.capacity,
        };
    }

    pub fn flush(self: *Encoder) void {
        if (self.parallel_state) |owner| {
            owner.flush();
            self.syncParallelState();
            return;
        }
        if (!self.finishing and !self.done) self.flush_requested = true;
    }

    pub fn finish(self: *Encoder) void {
        if (self.parallel_state) |owner| {
            owner.finish();
            self.syncParallelState();
            return;
        }
        if (!self.done) {
            self.finishing = true;
            self.flush_requested = false;
        }
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.parallel_state) |owner| {
            defer self.syncParallelState();
            self.options.recordEffectiveSettings();
            return owner.step(input, output, self.options.max_input_len, self.options.max_pending_output_len, self.options.max_block_count);
        }
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            self.options.recordEffectiveSettings();
            return .{ .status = .done };
        }
        if ((self.flush_requested or self.finishing) and input.len != 0)
            return error.TrailingData;
        if (self.finishing) if (self.expected_input_len) |expected| {
            if (self.current_input != expected) return error.SizeMismatch;
        };
        self.options.recordEffectiveSettings();

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.pending_offset != self.pending.items.len) {
                const remaining = self.pending.items[self.pending_offset..];
                const take = @min(output.len - output_written, remaining.len);
                const next_current_output = std.math.add(usize, self.current_output, take) catch return error.IntegerOverflow;
                const next_total_output = std.math.add(usize, self.total_output, take) catch return error.IntegerOverflow;
                @memcpy(output[output_written..][0..take], remaining[0..take]);
                self.pending_offset += take;
                output_written += take;
                self.current_output = next_current_output;
                self.total_output = next_total_output;
                if (self.pending_offset != self.pending.items.len)
                    return result(input_read, output_written, .need_output);
                self.pending.clearRetainingCapacity();
                self.pending_offset = 0;
            }

            if (!self.header_written) {
                const original_len = self.pending.items.len;
                errdefer self.pending.shrinkRetainingCapacity(original_len);
                try writer.appendStreamHeader(self.allocator, &self.pending, self.options.check);
                try self.checkPendingLimit();
                self.header_written = true;
                continue;
            }

            // A complete block can remain buffered after a recoverable output
            // limit/allocation error. Retry it even when no new input is offered.
            if (self.plain.items.len == self.options.block_size) {
                try self.emitBlock();
                continue;
            }

            if (input_read < input.len) {
                const room = self.options.block_size - self.plain.items.len;
                const take = @min(room, input.len - input_read);
                const next_input = std.math.add(usize, self.current_input, take) catch
                    return error.IntegerOverflow;
                const next_total_input = std.math.add(usize, self.total_input, take) catch return error.IntegerOverflow;
                if (next_input > self.options.max_input_len) return error.OutputLimitExceeded;
                if (self.expected_input_len) |expected|
                    if (next_input > expected) return error.SizeMismatch;
                try self.plain.appendSlice(self.allocator, input[input_read..][0..take]);
                input_read += take;
                self.current_input = next_input;
                self.total_input = next_total_input;
                if (self.plain.items.len == self.options.block_size) {
                    try self.emitBlock();
                    continue;
                }
                continue;
            }

            if (self.flush_requested or self.finishing) {
                if (self.finishing) {
                    if (self.expected_input_len) |expected|
                        if (self.current_input != expected) return error.SizeMismatch;
                }
                if (self.plain.items.len != 0) {
                    try self.emitBlock();
                    continue;
                }
                if (self.flush_requested) {
                    self.flush_requested = false;
                    return result(input_read, output_written, .need_input);
                }
                if (!self.footer_written) {
                    const original_len = self.pending.items.len;
                    errdefer self.pending.shrinkRetainingCapacity(original_len);
                    try writer.appendStreamEnd(
                        self.allocator,
                        &self.pending,
                        self.options.check,
                        self.records.items,
                    );
                    try self.checkPendingLimit();
                    self.footer_written = true;
                    continue;
                }
                const next_stream_count = std.math.add(usize, self.stream_count, 1) catch return error.IntegerOverflow;
                self.done = true;
                self.stream_count = next_stream_count;
                return result(input_read, output_written, .done);
            }

            return result(input_read, output_written, .need_input);
        }
    }

    fn emitBlock(self: *Encoder) Error!void {
        if (self.plain.items.len == 0) return error.InvalidBlockPlan;
        if (self.records.items.len >= self.options.max_block_count)
            return error.OutputLimitExceeded;
        const next_block_count = std.math.add(usize, self.block_count, 1) catch return error.IntegerOverflow;
        try self.records.ensureUnusedCapacity(self.allocator, 1);
        const original_len = self.pending.items.len;
        errdefer self.pending.shrinkRetainingCapacity(original_len);
        const record = try writer.appendBlock(
            self.allocator,
            &self.pending,
            self.plain.items,
            self.options.writerOptions(),
            self.options.payload_encoding,
        );
        try self.checkPendingLimit();
        self.records.appendAssumeCapacity(record);
        self.plain.clearRetainingCapacity();
        self.block_count = next_block_count;
    }

    fn checkPendingLimit(self: *const Encoder) Error!void {
        if (self.pending.items.len > self.options.max_pending_output_len)
            return error.OutputLimitExceeded;
    }

    /// Progress committed before the most recent failing step. Consumers must
    /// account for these caller bytes before propagating an encoder error.
    pub fn failedProgress(self: *const Encoder) ?core.Progress {
        return if (self.parallel_state) |owner|
            owner.failedProgress()
        else
            null;
    }

    fn syncParallelState(self: *Encoder) void {
        const owner = self.parallel_state orelse return;
        self.total_input = owner.state.total_input;
        self.total_output = owner.state.total_output;
        self.block_count = owner.state.block_count;
        self.stream_count = owner.state.stream_count;
        self.current_input = owner.state.current_input;
        self.current_output = owner.state.current_output;
        self.header_written = owner.state.header_written;
        self.footer_written = owner.state.footer_written;
        self.flush_requested = owner.state.flush_requested;
        self.finishing = owner.state.finishing;
        self.done = owner.state.done;
    }

    fn result(input_read: usize, output_written: usize, status: core.StepResult.Status) core.StepResult {
        return .{ .progress = .{ .input_read = input_read, .output_written = output_written }, .status = status };
    }
};

fn validateOptions(options: Encoder.Options) Encoder.Error!void {
    try writer.validateOptions(options.writerOptions());
    if (options.parallel) |parallel| try parallel.validate();
    if (options.max_pending_output_len == 0 or options.max_block_count == 0)
        return error.OutputLimitExceeded;
}

fn parallelConfig(options: Encoder.Options, expected_input_len: ?usize) Encoder.Error!parallel_types.Config {
    return .{
        .writer_options = options.writerOptions(),
        .payload_encoding = options.payload_encoding,
        .max_input_len = options.max_input_len,
        .max_pending_output_len = options.max_pending_output_len,
        .max_block_count = options.max_block_count,
        .expected_input_len = expected_input_len,
        .parallel = options.parallel orelse return error.InvalidBlockPlan,
    };
}
