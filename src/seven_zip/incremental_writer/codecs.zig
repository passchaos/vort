const std = @import("std");
const bzip2 = @import("../../bzip2.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const lzma = @import("../../lzma/incremental_encoder.zig");
const incremental_filters = @import("../../xz/incremental_filters.zig");
const lzma2 = @import("../../xz/lzma2_incremental_encoder.zig");
const aes = @import("../aes.zig");
const coders = @import("../coders.zig");
const ppmd7 = @import("../ppmd7.zig");

pub const Error = core.Error || deflate.Error || bzip2.IncrementalEncoder.Error ||
    lzma.Encoder.Error || lzma2.Encoder.Error || ppmd7.IncrementalEncoder.IncrementalError ||
    incremental_filters.Error || aes.Error || std.mem.Allocator.Error;

pub const Encoder = struct {
    allocator: std.mem.Allocator,
    pipeline: Pipeline,
    encryption: ?aes.IncrementalEncryptor = null,
    compressed: std.ArrayList(u8) = .empty,
    compressed_offset: usize = 0,
    finish_requested: bool = false,
    pipeline_done: bool = false,
    encryption_finish_sent: bool = false,
    done: bool = false,
    plain_output_size: u64 = 0,

    const staging_len: usize = 64 * 1024;

    pub fn init(
        allocator: std.mem.Allocator,
        options: coders.Options,
        expected_size: ?u64,
    ) Error!Encoder {
        var pipeline = try Pipeline.init(allocator, options, expected_size);
        errdefer pipeline.deinit();
        return .{
            .allocator = allocator,
            .pipeline = pipeline,
            .encryption = if (options.encryption) |encryption|
                try aes.IncrementalEncryptor.init(
                    allocator,
                    encryption,
                    options.encryption_stream_index,
                )
            else
                null,
        };
    }

    pub fn deinit(self: *Encoder) void {
        self.pipeline.deinit();
        if (self.encryption) |*encryption| encryption.deinit();
        self.compressed.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn finish(self: *Encoder) void {
        if (self.done or self.finish_requested) return;
        self.finish_requested = true;
        self.pipeline.finish();
    }

    pub fn aesUnpackSize(self: *const Encoder) ?u64 {
        return if (self.encryption == null) null else self.plain_output_size;
    }

    pub fn step(self: *Encoder, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.encryption == null) return self.pipeline.step(input, output);
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finish_requested and input.len != 0) return error.TrailingData;

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.compressed_offset != self.compressed.items.len) {
                const encrypted = try self.encryption.?.step(
                    self.compressed.items[self.compressed_offset..],
                    output[output_written..],
                );
                if (encrypted.progress.input_read > self.compressed.items.len - self.compressed_offset or
                    encrypted.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                self.compressed_offset += encrypted.progress.input_read;
                output_written += encrypted.progress.output_written;
                if (encrypted.status == .done) return error.InvalidBlockPlan;
                if (self.compressed_offset != self.compressed.items.len) {
                    if (encrypted.status != .need_output) return error.InvalidBlockPlan;
                    return pipelineResult(input_read, output_written, .need_output);
                }
                self.compressed.clearRetainingCapacity();
                self.compressed_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return pipelineResult(input_read, output_written, .need_output);
            }

            if (!self.pipeline_done) {
                try self.compressed.resize(self.allocator, staging_len);
                const encoded = try self.pipeline.step(
                    input[input_read..],
                    self.compressed.items,
                );
                if (encoded.progress.input_read > input.len - input_read or
                    encoded.progress.output_written > self.compressed.items.len)
                    return error.InvalidBlockPlan;
                input_read += encoded.progress.input_read;
                self.compressed.items.len = encoded.progress.output_written;
                self.plain_output_size = std.math.add(
                    u64,
                    self.plain_output_size,
                    @intCast(encoded.progress.output_written),
                ) catch return error.IntegerOverflow;
                if (encoded.status == .done) self.pipeline_done = true;
                if (self.compressed.items.len != 0) continue;
                if (input_read < input.len) {
                    if (encoded.progress.input_read == 0) return error.InvalidBlockPlan;
                    continue;
                }
                if (!self.pipeline_done)
                    return pipelineResult(input_read, output_written, encoded.status);
            }

            if (!self.encryption_finish_sent) {
                self.encryption.?.finish();
                self.encryption_finish_sent = true;
            }
            const encrypted = try self.encryption.?.step(&.{}, output[output_written..]);
            if (encrypted.progress.input_read != 0 or
                encrypted.progress.output_written > output.len - output_written)
                return error.InvalidBlockPlan;
            output_written += encrypted.progress.output_written;
            if (encrypted.status == .done) {
                self.done = true;
                return pipelineResult(input_read, output_written, .done);
            }
            if (encrypted.status != .need_output) return error.InvalidBlockPlan;
            return pipelineResult(input_read, output_written, .need_output);
        }
    }
};

pub const Pipeline = struct {
    allocator: std.mem.Allocator,
    codec: State,
    filter: ?incremental_filters.Encoder = null,
    filtered: std.ArrayList(u8) = .empty,
    filtered_offset: usize = 0,
    finishing: bool = false,
    filter_finished: bool = false,
    codec_finish_sent: bool = false,
    done: bool = false,

    const filter_chunk_len: usize = 64 * 1024;

    pub fn init(
        allocator: std.mem.Allocator,
        options: coders.Options,
        expected_size: ?u64,
    ) Error!Pipeline {
        var codec = try State.init(allocator, options, expected_size);
        errdefer codec.deinit();
        return .{
            .allocator = allocator,
            .codec = codec,
            .filter = if (options.filters.len == 0)
                null
            else
                try incremental_filters.Encoder.init(allocator, options.filters),
        };
    }

    pub fn deinit(self: *Pipeline) void {
        self.codec.deinit();
        if (self.filter) |*filter| filter.deinit();
        self.filtered.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn finish(self: *Pipeline) void {
        if (!self.done) self.finishing = true;
    }

    pub fn step(self: *Pipeline, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing and input.len != 0) return error.TrailingData;
        if (self.filter == null) return self.stepUnfiltered(input, output);

        var input_read: usize = 0;
        var output_written: usize = 0;
        while (true) {
            if (self.filtered_offset != self.filtered.items.len) {
                const stepped = try self.codec.step(
                    self.filtered.items[self.filtered_offset..],
                    output[output_written..],
                );
                if (stepped.progress.input_read > self.filtered.items.len - self.filtered_offset or
                    stepped.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                self.filtered_offset += stepped.progress.input_read;
                output_written += stepped.progress.output_written;
                if (stepped.status == .done) return error.InvalidBlockPlan;
                if (self.filtered_offset != self.filtered.items.len) {
                    if (stepped.status != .need_output) return error.InvalidBlockPlan;
                    return pipelineResult(input_read, output_written, .need_output);
                }
                self.filtered.clearRetainingCapacity();
                self.filtered_offset = 0;
                if (output_written == output.len and output.len != 0)
                    return pipelineResult(input_read, output_written, .need_output);
            }

            if (input_read < input.len) {
                const take = @min(filter_chunk_len, input.len - input_read);
                try self.filter.?.push(
                    input[input_read..][0..take],
                    false,
                    &self.filtered,
                );
                input_read += take;
                if (self.filtered.items.len > filter_chunk_len + 64)
                    return error.OutputLimitExceeded;
                continue;
            }

            if (self.finishing) {
                if (!self.filter_finished) {
                    try self.filter.?.push(&.{}, true, &self.filtered);
                    self.filter_finished = true;
                    continue;
                }
                if (!self.codec_finish_sent) {
                    self.codec.finish();
                    self.codec_finish_sent = true;
                }
                const stepped = try self.codec.step(&.{}, output[output_written..]);
                if (stepped.progress.input_read != 0 or
                    stepped.progress.output_written > output.len - output_written)
                    return error.InvalidBlockPlan;
                output_written += stepped.progress.output_written;
                if (stepped.status == .done) {
                    self.done = true;
                    return pipelineResult(input_read, output_written, .done);
                }
                if (stepped.status != .need_output) return error.InvalidBlockPlan;
                return pipelineResult(input_read, output_written, .need_output);
            }
            return pipelineResult(input_read, output_written, .need_input);
        }
    }

    fn stepUnfiltered(
        self: *Pipeline,
        input: []const u8,
        output: []u8,
    ) Error!core.StepResult {
        if (self.finishing and !self.codec_finish_sent) {
            self.codec.finish();
            self.codec_finish_sent = true;
        }
        const stepped = try self.codec.step(input, output);
        if (stepped.status == .done) {
            if (!self.finishing) return error.InvalidBlockPlan;
            self.done = true;
        }
        return stepped;
    }
};

pub const State = union(enum) {
    copy: Copy,
    deflate: deflate.RawDeflateIncrementalBestEncoder,
    bzip2: bzip2.IncrementalEncoder,
    lzma: RawLzma,
    lzma2: lzma2.Encoder,
    ppmd7: ppmd7.IncrementalEncoder,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        options: coders.Options,
        expected_size: ?u64,
    ) Error!Self {
        return switch (options.compression) {
            .copy => .{ .copy = .{} },
            .deflate => .{ .deflate = if (expected_size) |size|
                deflate.RawDeflateIncrementalBestEncoder.initExactSize(
                    allocator,
                    deflateOptions(options),
                    std.math.cast(usize, size) orelse return error.OutputLimitExceeded,
                )
            else
                deflate.RawDeflateIncrementalBestEncoder.initWithOptions(
                    allocator,
                    deflateOptions(options),
                ) },
            .bzip2 => .{ .bzip2 = if (expected_size) |size|
                try bzip2.IncrementalEncoder.initExactSize(
                    allocator,
                    bzip2Options(options),
                    std.math.cast(usize, size) orelse return error.OutputLimitExceeded,
                )
            else
                try bzip2.IncrementalEncoder.initWithOptions(
                    allocator,
                    bzip2Options(options),
                ) },
            .lzma => .{ .lzma = try RawLzma.init(allocator, options, expected_size) },
            .lzma2, .lzma2_stored => .{ .lzma2 = if (expected_size) |size|
                try lzma2.Encoder.initExactSize(
                    allocator,
                    lzma2Options(options),
                    std.math.cast(usize, size) orelse return error.OutputLimitExceeded,
                )
            else
                try lzma2.Encoder.init(allocator, lzma2Options(options)) },
            .ppmd7 => .{ .ppmd7 = if (expected_size) |size|
                try ppmd7.IncrementalEncoder.initExactSize(
                    allocator,
                    ppmdOptions(options),
                    std.math.cast(usize, size) orelse return error.OutputLimitExceeded,
                )
            else
                try ppmd7.IncrementalEncoder.init(allocator, ppmdOptions(options)) },
        };
    }

    pub fn validate(options: coders.Options) Error!void {
        switch (options.compression) {
            .copy => {},
            .deflate => try deflate.RawDeflateIncrementalBestEncoder.validateOptions(
                deflateOptions(options),
            ),
            .bzip2, .lzma, .lzma2, .lzma2_stored, .ppmd7 => {},
        }
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .copy => {},
            .deflate => |*encoder| encoder.deinit(),
            .bzip2 => |*encoder| encoder.deinit(),
            .lzma => |*encoder| encoder.deinit(),
            .lzma2 => |*encoder| encoder.deinit(),
            .ppmd7 => |*encoder| encoder.deinit(),
        }
        self.* = undefined;
    }

    pub fn finish(self: *Self) void {
        switch (self.*) {
            .copy => |*encoder| encoder.finish(),
            .deflate => |*encoder| encoder.finish(),
            .bzip2 => |*encoder| encoder.finish(),
            .lzma => |*encoder| encoder.finish(),
            .lzma2 => |*encoder| encoder.finish(),
            .ppmd7 => |*encoder| encoder.finish(),
        }
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            .copy => |*encoder| encoder.step(input, output),
            .deflate => |*encoder| encoder.step(input, output),
            .bzip2 => |*encoder| encoder.step(input, output),
            .lzma => |*encoder| encoder.step(input, output),
            .lzma2 => |*encoder| encoder.step(input, output),
            .ppmd7 => |*encoder| encoder.step(input, output),
        };
    }
};

const Copy = struct {
    finishing: bool = false,
    done: bool = false,

    fn finish(self: *Copy) void {
        if (!self.done) self.finishing = true;
    }

    fn step(self: *Copy, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.done) {
            if (input.len != 0) return error.TrailingData;
            return .{ .status = .done };
        }
        if (self.finishing) {
            if (input.len != 0) return error.TrailingData;
            self.done = true;
            return .{ .status = .done };
        }
        if (input.len == 0) return .{ .status = .need_input };
        if (output.len == 0) return .{ .status = .need_output };
        const count = @min(input.len, output.len);
        @memcpy(output[0..count], input[0..count]);
        return .{
            .progress = .{ .input_read = count, .output_written = count },
            .status = if (count == input.len) .need_input else .need_output,
        };
    }
};

const RawLzma = struct {
    encoder: lzma.Encoder,
    header_discarded: usize = 0,

    const alone_header_len: usize = 13;

    fn init(
        allocator: std.mem.Allocator,
        options: coders.Options,
        expected_size: ?u64,
    ) Error!RawLzma {
        const encoder_options = lzma.Encoder.Options{
            .properties = options.lzma_properties,
            .dictionary_size = options.lzma_dictionary_size,
            .size_mode = if (expected_size == null) .end_marker else .known,
        };
        const encoder = if (expected_size) |size|
            try lzma.Encoder.initExactSize(
                allocator,
                encoder_options,
                std.math.cast(usize, size) orelse return error.OutputLimitExceeded,
            )
        else
            try lzma.Encoder.initWithOptions(allocator, encoder_options);
        return .{ .encoder = encoder };
    }

    fn deinit(self: *RawLzma) void {
        self.encoder.deinit();
        self.* = undefined;
    }

    fn finish(self: *RawLzma) void {
        self.encoder.finish();
    }

    fn step(self: *RawLzma, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.header_discarded != alone_header_len) {
            var scratch: [alone_header_len]u8 = undefined;
            const remaining = alone_header_len - self.header_discarded;
            const discarded = try self.encoder.step(&.{}, scratch[0..remaining]);
            if (discarded.progress.input_read != 0) return error.InvalidBlockPlan;
            self.header_discarded += discarded.progress.output_written;
            if (self.header_discarded != alone_header_len) {
                if (discarded.progress.output_written == 0) return error.InvalidBlockPlan;
                return .{ .status = .need_output };
            }
        }
        return self.encoder.step(input, output);
    }
};

fn deflateOptions(options: coders.Options) deflate.RawDeflateIncrementalBestEncoder.Options {
    return .{
        .compression = deflate.optionsForZlibLevel(options.deflate_level) catch unreachable,
    };
}

fn bzip2Options(options: coders.Options) bzip2.IncrementalEncoder.Options {
    return .{ .block_size_100k = options.bzip2_block_size_100k };
}

fn lzma2Options(options: coders.Options) lzma2.Encoder.Options {
    return .{ .mode = if (options.compression == .lzma2) .compressed else .stored };
}

fn ppmdOptions(options: coders.Options) ppmd7.IncrementalEncoder.Options {
    return .{
        .order = options.ppmd_order,
        .memory_size = options.ppmd_memory_size,
    };
}

fn pipelineResult(
    input_read: usize,
    output_written: usize,
    status: core.StepResult.Status,
) core.StepResult {
    return .{
        .progress = .{ .input_read = input_read, .output_written = output_written },
        .status = status,
    };
}
