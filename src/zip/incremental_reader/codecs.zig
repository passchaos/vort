const std = @import("std");
const api = @import("api.zig");
const bzip2 = @import("../../bzip2.zig");
const checksum = @import("../../checksum.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const descriptor = @import("descriptor.zig");
const zstd = @import("../../zstd.zig");

pub const Error = deflate.Error || bzip2.Error || zstd.Error || error{
    InvalidZipArchive,
    SizeMismatch,
    IntegerOverflow,
};

pub const DeflateState = struct {
    decoder: deflate.RawDeflateIncrementalFixedLiteralDecoder,
    descriptor_layout: descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,

    const Self = @This();

    pub fn init(
        entry_limit: usize,
        history: []u8,
        descriptor_layout: descriptor.Layout,
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
        const drained = try self.decoder.step("", output);
        try self.account(drained.progress, output, &progress);
        if (drained.status == .done or drained.status == .need_output)
            return .{ .progress = progress, .status = drained.status };
        if (input.len == 0) return .{ .progress = progress, .status = .need_input };
        const output_offset = drained.progress.output_written;
        const supplied = try self.decoder.step(input, output[output_offset..]);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(_: *const Self) []const u8 {
        return &.{};
    }

    pub fn actualCompressedSize(self: *const Self) Error!usize {
        return self.compressed_size;
    }

    pub fn outputSize(self: *const Self) usize {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try checkedAdd(self.compressed_size, progress.input_read);
        self.uncompressed_size = try checkedAdd(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const Bzip2State = struct {
    decoder: bzip2.IncrementalDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,
    expected_compressed_size: ?usize,
    finish_requested: bool = false,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: usize,
        expected_compressed_size: ?usize,
        expected_uncompressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        return .{
            .decoder = bzip2.IncrementalDecoder.initWithOptions(allocator, .{
                .max_output_len = entry_limit,
                .max_compressed_block_len = reader_options.max_bzip2_compressed_block_len,
                .max_decoded_block_len = @min(entry_limit, reader_options.max_bzip2_decoded_block_len),
                .expected_output_len = expected_uncompressed_size,
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
        const drained = try self.decoder.step("", output);
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
        const supplied = try self.decoder.step(input[0..offer_len], output[output_offset..]);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!usize {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) usize {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try checkedAdd(self.compressed_size, progress.input_read);
        self.uncompressed_size = try checkedAdd(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

pub const ZstdState = struct {
    decoder: zstd.NativeIncrementalFrameDecoder,
    descriptor_layout: ?descriptor.Layout,
    crc: checksum.Crc32Best = checksum.Crc32Best.init(),
    compressed_size: usize = 0,
    uncompressed_size: usize = 0,
    expected_compressed_size: ?usize,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        reader_options: api.Options,
        entry_limit: usize,
        expected_compressed_size: ?usize,
        expected_uncompressed_size: ?usize,
        descriptor_layout: ?descriptor.Layout,
    ) Self {
        return .{
            .decoder = zstd.NativeIncrementalFrameDecoder.initWithOptions(allocator, .{
                .max_compressed_buffer_len = reader_options.max_zstd_compressed_buffer_len,
                .max_decoded_buffer_len = entry_limit,
                .expected_output_len = expected_uncompressed_size,
                .stop_after_first_frame = true,
            }),
            .descriptor_layout = descriptor_layout,
            .expected_compressed_size = expected_compressed_size,
        };
    }

    pub fn deinit(self: *Self) void {
        self.decoder.deinit();
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        var progress: core.Progress = .{};
        const drained = try self.decoder.step("", output);
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
        const supplied = try self.decoder.step(input[0..offer_len], output[output_offset..]);
        try self.account(supplied.progress, output[output_offset..], &progress);
        return .{ .progress = progress, .status = supplied.status };
    }

    pub fn layout(self: *const Self) ?descriptor.Layout {
        return self.descriptor_layout;
    }

    pub fn trailingInput(self: *const Self) []const u8 {
        return self.decoder.trailingInput();
    }

    pub fn actualCompressedSize(self: *const Self) Error!usize {
        const trailing = self.trailingInput();
        if (trailing.len > self.compressed_size) return error.InvalidZipArchive;
        return self.compressed_size - trailing.len;
    }

    pub fn outputSize(self: *const Self) usize {
        return self.uncompressed_size;
    }

    pub fn crc32(self: *const Self) u32 {
        return self.crc.digest();
    }

    fn account(
        self: *Self,
        progress: core.Progress,
        output: []const u8,
        aggregate: *core.Progress,
    ) Error!void {
        self.compressed_size = try checkedAdd(self.compressed_size, progress.input_read);
        self.uncompressed_size = try checkedAdd(self.uncompressed_size, progress.output_written);
        self.crc.update(output[0..progress.output_written]);
        try aggregate.add(progress);
    }
};

fn inputOffer(
    layout: ?descriptor.Layout,
    expected_compressed_size: ?usize,
    accepted_input: usize,
    available_input: usize,
) Error!usize {
    if (layout) |descriptor_layout|
        return @min(available_input, descriptor_layout.unsignedLen());
    const expected = expected_compressed_size orelse return error.InvalidZipArchive;
    if (accepted_input > expected) return error.SizeMismatch;
    return @min(available_input, expected - accepted_input);
}

fn checkedAdd(a: usize, b: usize) error{IntegerOverflow}!usize {
    return std.math.add(usize, a, b) catch error.IntegerOverflow;
}
