const std = @import("std");
const bzip2 = @import("../../bzip2.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const lzma_codec = @import("lzma_codec.zig");
const types = @import("../types.zig");
const zstd = @import("../../zstd.zig");
const xz = @import("../../xz.zig");

pub const CompressionMethod = types.CompressionMethod;
pub const DeflateOptions = deflate.RawDeflateIncrementalBestEncoder.Options;
pub const Bzip2Options = bzip2.IncrementalEncoder.Options;
pub const ZstdOptions = zstd.NativeFrameOptions;
pub const LzmaOptions = lzma_codec.Options;
pub const XzOptions = xz.IncrementalEncoder.Options;
pub const XzFilter = xz.Filter;

pub const Error = deflate.Error || bzip2.IncrementalEncoder.Error || zstd.Error || lzma_codec.Error || xz.IncrementalEncoder.Error || std.mem.Allocator.Error || error{
    UnsupportedZipCompressionMethod,
};

pub const Options = struct {
    deflate: DeflateOptions,
    max_deflate_buffer_size: usize,
    bzip2: Bzip2Options,
    zstd: ZstdOptions,
    lzma: LzmaOptions,
    xz: XzOptions,
};

pub const State = union(enum) {
    stored,
    deflate: deflate.RawDeflateIncrementalBestEncoder,
    bzip2: bzip2.IncrementalEncoder,
    zstd: zstd.NativeIncrementalFrameEncoder,
    lzma: lzma_codec.State,
    xz: xz.IncrementalEncoder,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        method: CompressionMethod,
        expected_size: ?u64,
        options: Options,
    ) Error!Self {
        try validate(method, expected_size, options);
        return switch (method) {
            .stored => .stored,
            .deflate => .{ .deflate = if (expected_size) |expected|
                deflate.RawDeflateIncrementalBestEncoder.initExactSize(
                    allocator,
                    options.deflate,
                    @intCast(expected),
                )
            else
                deflate.RawDeflateIncrementalBestEncoder.initWithOptions(
                    allocator,
                    options.deflate,
                ) },
            .bzip2 => .{ .bzip2 = if (expected_size) |expected|
                try bzip2.IncrementalEncoder.initExactSize(
                    allocator,
                    options.bzip2,
                    @intCast(expected),
                )
            else
                try bzip2.IncrementalEncoder.initWithOptions(
                    allocator,
                    options.bzip2,
                ) },
            .zstandard_legacy, .zstandard => zstd_state: {
                var zstd_options = options.zstd;
                zstd_options.include_content_size = expected_size != null;
                break :zstd_state .{ .zstd = if (expected_size) |expected|
                    try zstd.NativeIncrementalFrameEncoder.initExactSize(
                        allocator,
                        zstd_options,
                        @intCast(expected),
                    )
                else
                    try zstd.NativeIncrementalFrameEncoder.init(
                        allocator,
                        zstd_options,
                    ) };
            },
            .lzma => .{ .lzma = try lzma_codec.State.init(
                allocator,
                options.lzma,
                expected_size,
            ) },
            .xz => .{ .xz = if (expected_size) |expected|
                try xz.IncrementalEncoder.initExactSize(
                    allocator,
                    options.xz,
                    @intCast(expected),
                )
            else
                try xz.IncrementalEncoder.initWithOptions(
                    allocator,
                    options.xz,
                ) },
            else => error.UnsupportedZipCompressionMethod,
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .stored => {},
            .deflate => |*encoder| encoder.deinit(),
            .bzip2 => |*encoder| encoder.deinit(),
            .zstd => |*encoder| encoder.deinit(),
            .lzma => |*encoder| encoder.deinit(),
            .xz => |*encoder| encoder.deinit(),
        }
        self.* = undefined;
    }

    pub fn finish(self: *Self) void {
        switch (self.*) {
            .stored => {},
            .deflate => |*encoder| encoder.finish(),
            .bzip2 => |*encoder| encoder.finish(),
            .zstd => |*encoder| encoder.finish(),
            .lzma => |*encoder| encoder.finish(),
            .xz => |*encoder| encoder.finish(),
        }
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            .stored => error.InvalidBlockPlan,
            .deflate => |*encoder| encoder.step(input, output),
            .bzip2 => |*encoder| encoder.step(input, output),
            .zstd => |*encoder| encoder.step(input, output),
            .lzma => |*encoder| encoder.step(input, output),
            .xz => |*encoder| encoder.step(input, output),
        };
    }
};

pub fn validate(
    method: CompressionMethod,
    expected_size: ?u64,
    options: Options,
) Error!void {
    switch (method) {
        .stored => {},
        .deflate => {
            try deflate.RawDeflateIncrementalBestEncoder.validateOptions(options.deflate);
            const retained = try deflate.RawDeflateIncrementalBestEncoder.maxBufferedInput(
                options.deflate,
            );
            if (retained > options.max_deflate_buffer_size)
                return error.OutputLimitExceeded;
            try validateExpectedSize(expected_size, options.deflate.max_input_len);
        },
        .bzip2 => {
            if (options.bzip2.block_size_100k < 1 or options.bzip2.block_size_100k > 9)
                return error.InvalidBzip2Header;
            if (options.bzip2.max_pending_output_len == 0)
                return error.OutputLimitExceeded;
            try validateExpectedSize(expected_size, options.bzip2.max_input_len);
        },
        .zstandard_legacy, .zstandard => {
            if (options.zstd.dictionary_id != 0) return error.InvalidBlockPlan;
            try validateExpectedSize(expected_size, std.math.maxInt(usize));
        },
        .lzma => {
            if (options.lzma.dictionary_size < 4096 or
                options.lzma.dictionary_size > std.math.maxInt(u16))
                return error.InvalidLzmaOptions;
            try validateExpectedSize(expected_size, options.lzma.max_input_len);
        },
        .xz => {
            if (options.xz.block_size == 0 or options.xz.dictionary_size < 4096 or
                options.xz.max_pending_output_len == 0 or options.xz.max_block_count == 0)
                return error.InvalidBlockPlan;
            try validateExpectedSize(expected_size, options.xz.max_input_len);
        },
        else => return error.UnsupportedZipCompressionMethod,
    }
}

pub fn inputLimit(method: CompressionMethod, options: Options) ?usize {
    return switch (method) {
        .deflate => options.deflate.max_input_len,
        .bzip2 => options.bzip2.max_input_len,
        .zstandard_legacy, .zstandard => std.math.maxInt(usize),
        .lzma => options.lzma.max_input_len,
        .xz => options.xz.max_input_len,
        else => null,
    };
}

pub fn zipFlags(state: *const State) u16 {
    return switch (state.*) {
        .lzma => 1 << 1,
        else => 0,
    };
}

fn validateExpectedSize(expected_size: ?u64, max_input_len: usize) Error!void {
    if (expected_size) |expected| {
        const expected_usize = std.math.cast(usize, expected) orelse
            return error.OutputLimitExceeded;
        if (expected_usize > max_input_len) return error.OutputLimitExceeded;
    }
}
