const std = @import("std");
const api = @import("api.zig");
const bzip2 = @import("../../bzip2.zig");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const deflate64 = @import("../../deflate64.zig");
const descriptor = @import("descriptor.zig");
const dcl_codec = @import("dcl_codec.zig");
const implode_codec = @import("implode_codec.zig");
const lzma = @import("../../lzma.zig");
const ppmd_codec = @import("ppmd_codec.zig");
const reduce_codec = @import("reduce_codec.zig");
const shrink_codec = @import("shrink_codec.zig");
const wire = @import("../wire.zig");
const xz = @import("../../xz.zig");
const terminal = @import("terminal_byte_codec.zig");
const zstd = @import("../../zstd.zig");

pub const Error = deflate.Error || deflate64.Error || dcl_codec.Error || implode_codec.Error || bzip2.Error || lzma.Error || ppmd_codec.Error || reduce_codec.Error || shrink_codec.Error || xz.Error || zstd.Error || error{
    InvalidZipArchive,
    UnsupportedZipFeature,
    SizeMismatch,
    IntegerOverflow,
};

pub const DclImplodeState = dcl_codec.State;
pub const ImplodeState = implode_codec.State;
pub const PpmdZipState = ppmd_codec.State;
pub const ReduceFactor = reduce_codec.Factor;
pub const ReduceState = reduce_codec.State;
pub const ShrinkState = shrink_codec.State;

pub const Deflate64State = struct {
    allocator: std.mem.Allocator,
    history: []u8,
    decoder: deflate64.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        const history = try allocator.alloc(u8, deflate64.IncrementalDecoder.required_history_len);
        errdefer allocator.free(history);
        return .{
            .allocator = allocator,
            .history = history,
            .decoder = try deflate64.IncrementalDecoder.initWithHistory(.{
                .max_output_len = entry_limit,
                .expected_output_len = expected_uncompressed_size,
                .allow_trailing_data = true,
            }, history),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.history);
        self.* = undefined;
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };

        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            input.len,
        );
        if (offer_len == 0) {
            if (input.len == 0) return .{ .progress = progress, .status = .need_input };
            try self.decoder.finish();
            return error.TruncatedFrame;
        }
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(_: *const Self) []const u8 {
        return &.{};
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        return self.compressed_size;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const LzmaZipState = struct {
    decoder: lzma.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    expected_uncompressed_size: ?core.StreamCount,
    end_marker: bool,
    prefix: [9]u8 = undefined,
    prefix_len: usize = 0,
    header_fed: bool = false,
    finish_requested: bool = false,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: core.StreamCount,
        flags: u16,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        const end_marker = flags & wire.lzma_end_marker_flag != 0;
        if (descriptor_layout != null and !end_marker)
            return error.UnsupportedZipFeature;
        return .{
            .decoder = lzma.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = core.stream_count.bounded(entry_limit, std.math.maxInt(usize)),
                .max_dictionary_size = reader_options.max_lzma_dictionary_size,
                .max_compressed_buffer_len = reader_options.max_lzma_compressed_buffer_len,
                .expected_output_len = try terminal.toOptionalLocal(expected_uncompressed_size),
                .stop_after_end_marker = descriptor_layout != null,
                .end_marker_input_guard = if (descriptor_layout) |layout_value|
                    layout_value.unsignedLen()
                else
                    0,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
            .expected_uncompressed_size = expected_uncompressed_size,
            .end_marker = end_marker,
        };
    }

    pub fn deinit(self: *Self) void {
        self.decoder.deinit();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        if (!self.header_fed) {
            const available = core.stream_count.bounded(std.math.maxInt(core.StreamCount) - self.compressed_size, input.len);
            const take = @min(self.prefix.len - self.prefix_len, available);
            @memcpy(self.prefix[self.prefix_len..][0..take], input[0..take]);
            self.prefix_len += take;
            self.compressed_size = try core.stream_count.addLocal(self.compressed_size, take);
            progress.input_read += take;
            if (self.prefix_len != self.prefix.len) {
                if (available != input.len) return error.IntegerOverflow;
                return .{ .progress = progress, .status = .need_input };
            }
            try self.feedSyntheticHeader();
        }

        if (self.expected_compressed_size) |expected| {
            if (self.compressed_size == expected and !self.finish_requested) {
                self.decoder.finish();
                self.finish_requested = true;
            }
        }
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };

        const remaining_input = input[progress.input_read..];
        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            remaining_input.len,
        );
        if (offer_len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(remaining_input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn feedSyntheticHeader(self: *Self) Error!void {
        if (std.mem.readInt(u16, self.prefix[2..4], .little) != 5)
            return error.InvalidLzmaHeader;
        var header: [13]u8 = undefined;
        @memcpy(header[0..5], self.prefix[4..9]);
        const output_size: u64 = if (self.end_marker)
            std.math.maxInt(u64)
        else
            self.expected_uncompressed_size orelse return error.InvalidZipArchive;
        std.mem.writeInt(u64, header[5..13], output_size, .little);
        const primed = try self.decoder.step(&header, &.{});
        if (primed.progress.input_read != header.len or primed.progress.output_written != 0 or
            primed.status != .need_input)
            return error.InvalidLzmaStream;
        self.header_fed = true;
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const DeflateState = struct {
    decoder: deflate.RawDeflateIncrementalFixedLiteralDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},

    const Self = @This();

    pub fn init(
        entry_limit: core.StreamCount,
        history: []u8,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        return .{
            .decoder = try deflate.RawDeflateIncrementalFixedLiteralDecoder.initWithHistory(.{
                .max_output_len = entry_limit,
                .allow_trailing_data = true,
            }, history),
            .descriptor_layout = descriptor_layout,
        };
    }

    pub fn deinit(_: *Self) void {}

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        // Drain a buffered EOB before supplying bytes that may belong to the
        // following ZIP descriptor. This mirrors the zlib/gzip wrappers.
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };
        if (input.len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input, output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(_: *const Self) []const u8 {
        return &.{};
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        return self.compressed_size;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const Bzip2State = struct {
    decoder: bzip2.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},
    expected_compressed_size: ?core.StreamCount,
    finish_requested: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        return .{
            .decoder = bzip2.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = core.stream_count.bounded(entry_limit, std.math.maxInt(usize)),
                .max_compressed_block_len = reader_options.max_bzip2_compressed_block_len,
                .max_decoded_block_len = core.stream_count.bounded(entry_limit, reader_options.max_bzip2_decoded_block_len),
                .expected_output_len = try terminal.toOptionalLocal(expected_uncompressed_size),
                .stop_after_first_stream = true,
                .first_stream_retry_granularity = if (descriptor_layout) |layout_value|
                    layout_value.unsignedLen()
                else
                    0,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.decoder.deinit();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.expected_compressed_size) |expected| {
            if (self.compressed_size == expected and !self.finish_requested) {
                self.decoder.finish();
                self.finish_requested = true;
            }
        }

        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };

        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            input.len,
        );
        if (offer_len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const XzState = struct {
    decoder: xz.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},
    expected_compressed_size: ?core.StreamCount,
    finish_requested: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Error!Self {
        return .{
            .decoder = xz.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = core.stream_count.bounded(entry_limit, std.math.maxInt(usize)),
                .max_dictionary_size = reader_options.max_xz_dictionary_size,
                .max_compressed_block_len = reader_options.max_xz_compressed_block_len,
                .max_decoded_block_len = core.stream_count.bounded(entry_limit, reader_options.max_xz_decoded_block_len),
                .max_index_footer_len = reader_options.max_xz_index_footer_len,
                .max_block_count = reader_options.max_xz_block_count,
                .expected_output_len = try terminal.toOptionalLocal(expected_uncompressed_size),
                .stop_after_first_stream = descriptor_layout != null,
                .first_stream_footer_retry_granularity = if (descriptor_layout) |layout_value|
                    layout_value.unsignedLen()
                else
                    0,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.decoder.deinit();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        if (self.expected_compressed_size) |expected| {
            if (self.compressed_size == expected and !self.finish_requested) {
                self.decoder.finish();
                self.finish_requested = true;
            }
        }
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };

        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            input.len,
        );
        if (offer_len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const ZstdState = struct {
    decoder: zstd.NativeIncrementalFrameDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: core.StreamCount = 0,
    uncompressed_size: core.StreamCount = 0,
    last_step_progress: core.Progress = .{},
    expected_compressed_size: ?core.StreamCount,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: core.StreamCount,
        expected_compressed_size: ?core.StreamCount,
        expected_uncompressed_size: ?core.StreamCount,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        const decoder_options: zstd.NativeIncrementalFrameDecoder.Options = .{
            .max_compressed_buffer_len = reader_options.max_zstd_compressed_buffer_len,
            .max_decoded_buffer_len = entry_limit,
            .expected_output_len = expected_uncompressed_size,
            .stop_after_first_frame = true,
        };
        return .{
            .decoder = if (reader_options.zstd_dictionary) |dictionary|
                zstd.NativeIncrementalFrameDecoder.initWithDictionaryAndOptions(
                    allocator,
                    dictionary,
                    decoder_options,
                )
            else
                zstd.NativeIncrementalFrameDecoder.initWithOptions(
                    allocator,
                    decoder_options,
                ),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.decoder.deinit();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        defer self.last_step_progress = progress;
        const drained = try self.decode("", output, &progress);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };

        if (self.expected_compressed_size) |expected| {
            if (self.compressed_size == expected) {
                try self.decoder.finish();
                return .{ .progress = progress, .status = .done };
            }
        }
        const offer_len = try inputOffer(
            self.descriptor_layout,
            self.expected_compressed_size,
            self.compressed_size,
            input.len,
        );
        if (offer_len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decode(input[0..offer_len], output[output_offset..], &progress);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!core.StreamCount {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) core.StreamCount {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn decode(self: *Self, input: []const u8, output: []u8, aggregate: *core.Progress) Error!core.StepResult {
        return terminal.decode(Error, self, &self.decoder, input, output, aggregate, Self.account);
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try core.stream_count.addLocal(self.compressed_size, progress.input_read);
        self.uncompressed_size = try core.stream_count.addLocal(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

fn inputOffer(
    layout: ?descriptor.Layout,
    expected_compressed_size: ?core.StreamCount,
    accepted_input: core.StreamCount,
    available_input: usize,
) Error!usize {
    if (layout) |descriptor_layout|
        return @min(available_input, descriptor_layout.unsignedLen());
    const expected = expected_compressed_size orelse return available_input;
    if (accepted_input > expected) return error.SizeMismatch;
    return core.stream_count.bounded(expected - accepted_input, available_input);
}

test "ZIP codec adapter counts remain logical while progress is physical" {
    inline for (.{ DeflateState, Deflate64State, LzmaZipState, Bzip2State, XzState, ZstdState, DclImplodeState, PpmdZipState, ShrinkState, ReduceState, ImplodeState }) |StateType| {
        try std.testing.expect(@FieldType(StateType, "compressed_size") == core.StreamCount);
        try std.testing.expect(@FieldType(StateType, "uncompressed_size") == core.StreamCount);
        try std.testing.expect(@FieldType(StateType, "last_step_progress") == core.Progress);
        try std.testing.expect(@typeInfo(@TypeOf(StateType.outputSize)).@"fn".return_type.? == core.StreamCount);
    }
    try std.testing.expect(@FieldType(core.Progress, "input_read") == usize);
    try std.testing.expect(@FieldType(core.Progress, "output_written") == usize);
}

test "ZIP codec adapter bounds input offers after the 32 bit boundary" {
    const boundary = @as(core.StreamCount, 1) << 32;
    try std.testing.expectEqual(@as(usize, 5), try inputOffer(null, boundary + 7, boundary + 2, 9));
    try std.testing.expectEqual(@as(usize, 9), try inputOffer(null, std.math.maxInt(core.StreamCount), boundary, 9));
    try std.testing.expectEqual(@as(usize, 0), try inputOffer(null, boundary, boundary, 9));
    try std.testing.expectError(error.SizeMismatch, inputOffer(null, boundary, boundary + 1, 9));
}

test "ZIP codec adapter accounts partial output and CRC after decoder failure" {
    const malformed = [_]u8{ 0x00, 3, 0, 0xfc, 0xff, 'a', 'b', 'c', 0x07 };
    var history: [deflate.RawDeflateIncrementalFixedLiteralDecoder.required_history_len]u8 = undefined;
    var state = try DeflateState.init(std.math.maxInt(core.StreamCount), &history, null);
    defer state.deinit();
    var output: [8]u8 = @splat(0xa5);
    try std.testing.expectError(error.InvalidDeflateBlockType, state.step(&malformed, &output));
    try std.testing.expectEqualDeep(core.Progress{ .input_read = malformed.len, .output_written = 3 }, state.last_step_progress);
    try std.testing.expectEqual(@as(core.StreamCount, 3), state.outputSize());
    try std.testing.expectEqual(state.decoder.total_input, try state.actualCompressedSize());
    try std.testing.expectEqual(checksum.crc32Best("abc"), state.crc32());
    try std.testing.expectEqualSlices(u8, "abc", output[0..3]);
    try std.testing.expectEqualSlices(u8, &@as([5]u8, @splat(0xa5)), output[3..]);
    _ = try state.step("", &output);
    try std.testing.expectEqualDeep(core.Progress{}, state.last_step_progress);
}

test "ZIP codec adapter clamps output before logical count overflow" {
    const stored = [_]u8{ 0x01, 3, 0, 0xfc, 0xff, 'a', 'b', 'c' };
    var history: [deflate.RawDeflateIncrementalFixedLiteralDecoder.required_history_len]u8 = undefined;
    var state = try DeflateState.init(std.math.maxInt(core.StreamCount), &history, null);
    defer state.deinit();
    state.uncompressed_size = std.math.maxInt(core.StreamCount) - 1;
    var output: [4]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, state.step(&stored, &output));
    try std.testing.expectEqual(std.math.maxInt(core.StreamCount), state.outputSize());
    try std.testing.expectEqualDeep(core.Progress{ .input_read = 6, .output_written = 1 }, state.last_step_progress);
    try std.testing.expectEqual(checksum.crc32Best("a"), state.crc32());
    try std.testing.expectEqual(@as(u8, 'a'), output[0]);
    try std.testing.expectEqualSlices(u8, &@as([3]u8, @splat(0xa5)), output[1..]);
}

test "ZIP codec adapter legacy default limits remain usable on narrow targets" {
    const allocator = std.testing.allocator;
    const limit = std.math.maxInt(core.StreamCount);
    var lzma_state = try LzmaZipState.init(allocator, .{}, limit, 0, null, null, null);
    defer lzma_state.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), lzma_state.decoder.options.max_output_len);
    var ppmd_state = PpmdZipState.init(allocator, .{}, limit, null, null, null);
    defer ppmd_state.deinit();
    const ppmd_header = try ppmd_state.step(&.{ 0x07, 0x00 }, &.{});
    try std.testing.expectEqual(@as(usize, 2), ppmd_header.progress.input_read);
    try std.testing.expectEqual(std.math.maxInt(usize), ppmd_state.decoder.?.options.max_output_len);
    var dcl = try DclImplodeState.init(limit, null, null, null);
    defer dcl.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), dcl.decoder.options.max_output_len);
    var bzip = try Bzip2State.init(allocator, .{}, limit, null, null, null);
    defer bzip.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), bzip.decoder.options.max_output_len);
    var xz_state = try XzState.init(allocator, .{}, limit, null, null, null);
    defer xz_state.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), xz_state.decoder.options.max_output_len);
    var shrink_state = try ShrinkState.init(allocator, limit, null, null, null, 0, 0, true);
    defer shrink_state.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), shrink_state.decoder.options.max_output_len);
    var reduce_state = try ReduceState.init(allocator, .factor_1, limit, null, null, null, 0, 0, true);
    defer reduce_state.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), reduce_state.decoder.options.max_output_len);
    var implode_state = try ImplodeState.init(allocator, 0, limit, null, null, null, 0, 0, true);
    defer implode_state.deinit();
    try std.testing.expectEqual(std.math.maxInt(usize), implode_state.decoder.options.max_output_len);
    if (@bitSizeOf(usize) < 64) {
        const pledge = @as(core.StreamCount, std.math.maxInt(usize)) + 1;
        try std.testing.expectError(error.IntegerOverflow, LzmaZipState.init(allocator, .{}, limit, 0, null, pledge, null));
        var ppmd_wide = PpmdZipState.init(allocator, .{}, limit, null, pledge, null);
        defer ppmd_wide.deinit();
        try std.testing.expectError(error.IntegerOverflow, ppmd_wide.step(&.{ 0x07, 0x00 }, &.{}));
        try std.testing.expectError(error.IntegerOverflow, DclImplodeState.init(limit, null, pledge, null));
        try std.testing.expectError(error.IntegerOverflow, Bzip2State.init(allocator, .{}, limit, null, pledge, null));
        try std.testing.expectError(error.IntegerOverflow, XzState.init(allocator, .{}, limit, null, pledge, null));
        try std.testing.expectError(error.IntegerOverflow, ShrinkState.init(allocator, limit, null, pledge, null, 0, 0, true));
        try std.testing.expectError(error.IntegerOverflow, ReduceState.init(allocator, .factor_1, limit, null, pledge, null, 0, 0, true));
        try std.testing.expectError(error.IntegerOverflow, ImplodeState.init(allocator, 0, limit, null, pledge, null, 0, 0, true));
    }
}

test {
    _ = shrink_codec;
    _ = terminal;
}

test "ZIP codec adapter wide Deflate cores cross cumulative 32 bit boundaries" {
    const boundary = @as(core.StreamCount, 1) << 32;
    const stored = [_]u8{ 0x01, 3, 0, 0xfc, 0xff, 'a', 'b', 'c' };
    const allocator = std.testing.allocator;
    var state = try Deflate64State.init(allocator, std.math.maxInt(core.StreamCount), boundary + 4, boundary + 1, null);
    defer state.deinit();
    state.compressed_size = boundary - 4;
    state.uncompressed_size = boundary - 2;
    state.decoder.total_input = state.compressed_size;
    state.decoder.total_output = state.uncompressed_size;
    var output: [3]u8 = undefined;
    const stepped = try state.step(&stored, &output);
    try std.testing.expectEqual(core.StepResult.Status.done, stepped.status);
    try std.testing.expectEqual(@as(usize, stored.len), stepped.progress.input_read);
    try std.testing.expectEqual(@as(usize, output.len), stepped.progress.output_written);
    try std.testing.expectEqual(boundary + 4, try state.actualCompressedSize());
    try std.testing.expectEqual(boundary + 1, state.outputSize());
    try std.testing.expectEqual(checksum.crc32Best("abc"), state.crc32());
    try std.testing.expectEqualSlices(u8, "abc", &output);
    var zstd_state = ZstdState.init(allocator, .{}, std.math.maxInt(core.StreamCount), boundary + 4, boundary + 1, null);
    defer zstd_state.deinit();
    try std.testing.expectEqual(@as(?core.StreamCount, boundary + 1), zstd_state.decoder.options.expected_output_len);
    try std.testing.expectEqual(std.math.maxInt(core.StreamCount), zstd_state.decoder.options.max_decoded_buffer_len);
}
