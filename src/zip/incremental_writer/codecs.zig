const std = @import("std");
const bzip2 = @import("../../bzip2.zig");
const core = @import("../../core.zig");
const deflate = @import("../../deflate.zig");
const deflate64 = @import("../../deflate64.zig");
const dcl_implode = @import("../dcl_implode.zig");
const dcl_implode_encoder = @import("../dcl_implode/incremental_encoder.zig");
const implode = @import("../implode.zig");
const implode_encoder = @import("../implode/incremental_encoder.zig");
const lzma_codec = @import("lzma_codec.zig");
const ppmd_codec = @import("ppmd_codec.zig");
const reduce = @import("../reduce.zig");
const reduce_encoder = @import("../reduce/incremental_encoder.zig");
const shrink = @import("../shrink.zig");
const types = @import("../types.zig");
const zstd = @import("../../zstd.zig");
const xz = @import("../../xz.zig");

pub const CompressionMethod = types.CompressionMethod;
pub const DeflateOptions = deflate.RawDeflateIncrementalBestEncoder.Options;
pub const Deflate64Options = deflate64.IncrementalStoredEncoder.Options;
pub const DclImplodeOptions = dcl_implode_encoder.Encoder.Options;
pub const ImplodeOptions = implode_encoder.Encoder.Options;
pub const Bzip2Options = bzip2.IncrementalEncoder.Options;
pub const ZstdOptions = zstd.NativeFrameOptions;
pub const LzmaOptions = lzma_codec.Options;
pub const XzOptions = xz.IncrementalEncoder.Options;
pub const XzFilter = xz.Filter;
pub const PpmdOptions = ppmd_codec.Options;
pub const ReduceOptions = reduce_encoder.Encoder.Options;
pub const ShrinkOptions = shrink.IncrementalEncoder.Options;

pub const Error = deflate.Error || deflate64.Error || dcl_implode.Error || implode.Error || reduce.Error || bzip2.IncrementalEncoder.Error || zstd.Error || lzma_codec.Error || xz.IncrementalEncoder.Error || ppmd_codec.Error || shrink.Error || std.mem.Allocator.Error || error{
    UnsupportedZipCompressionMethod,
};

pub const Options = struct {
    deflate: DeflateOptions,
    max_deflate_buffer_size: usize,
    deflate64: Deflate64Options,
    dcl_implode: DclImplodeOptions,
    implode: ImplodeOptions,
    bzip2: Bzip2Options,
    zstd: ZstdOptions,
    lzma: LzmaOptions,
    xz: XzOptions,
    ppmd: PpmdOptions,
    reduce: ReduceOptions,
    shrink: ShrinkOptions,
};

pub const State = union(enum) {
    stored,
    deflate: deflate.RawDeflateIncrementalBestEncoder,
    deflate64: deflate64.IncrementalStoredEncoder,
    dcl_implode: dcl_implode_encoder.Encoder,
    implode: implode_encoder.Encoder,
    bzip2: bzip2.IncrementalEncoder,
    zstd: zstd.NativeIncrementalFrameEncoder,
    lzma: lzma_codec.State,
    xz: xz.IncrementalEncoder,
    ppmd: ppmd_codec.State,
    reduce: reduce_encoder.Encoder,
    shrink: shrink.IncrementalEncoder,

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
            .deflate64 => .{ .deflate64 = if (expected_size) |expected|
                deflate64.IncrementalStoredEncoder.initExactSize(
                    allocator,
                    options.deflate64,
                    @intCast(expected),
                )
            else
                deflate64.IncrementalStoredEncoder.initWithOptions(
                    allocator,
                    options.deflate64,
                ) },
            .dcl_implode => .{ .dcl_implode = if (expected_size) |expected|
                try dcl_implode_encoder.Encoder.initExactSize(
                    allocator,
                    options.dcl_implode,
                    @intCast(expected),
                )
            else
                try dcl_implode_encoder.Encoder.initWithOptions(
                    allocator,
                    options.dcl_implode,
                ) },
            .implode => .{ .implode = if (expected_size) |expected|
                try implode_encoder.Encoder.initExactSize(
                    allocator,
                    options.implode,
                    @intCast(expected),
                )
            else
                try implode_encoder.Encoder.initWithOptions(
                    allocator,
                    options.implode,
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
            .ppmd => .{ .ppmd = try ppmd_codec.State.init(
                allocator,
                options.ppmd,
                expected_size,
            ) },
            .reduce_1, .reduce_2, .reduce_3, .reduce_4 => .{ .reduce = if (expected_size) |expected|
                try reduce_encoder.Encoder.initExactSize(
                    allocator,
                    reduceFactor(method).?,
                    options.reduce,
                    @intCast(expected),
                )
            else
                try reduce_encoder.Encoder.initWithOptions(
                    allocator,
                    reduceFactor(method).?,
                    options.reduce,
                ) },
            .shrink => .{ .shrink = if (expected_size) |expected|
                try shrink.IncrementalEncoder.initExactSize(
                    allocator,
                    options.shrink,
                    @intCast(expected),
                )
            else
                try shrink.IncrementalEncoder.initWithOptions(
                    allocator,
                    options.shrink,
                ) },
            else => error.UnsupportedZipCompressionMethod,
        };
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            .stored => {},
            .deflate => |*encoder| encoder.deinit(),
            .deflate64 => |*encoder| encoder.deinit(),
            .dcl_implode => |*encoder| encoder.deinit(),
            .implode => |*encoder| encoder.deinit(),
            .bzip2 => |*encoder| encoder.deinit(),
            .zstd => |*encoder| encoder.deinit(),
            .lzma => |*encoder| encoder.deinit(),
            .xz => |*encoder| encoder.deinit(),
            .ppmd => |*encoder| encoder.deinit(),
            .reduce => |*encoder| encoder.deinit(),
            .shrink => |*encoder| encoder.deinit(),
        }
        self.* = undefined;
    }

    pub fn finish(self: *Self) void {
        switch (self.*) {
            .stored => {},
            .deflate => |*encoder| encoder.finish(),
            .deflate64 => |*encoder| encoder.finish(),
            .dcl_implode => |*encoder| encoder.finish(),
            .implode => |*encoder| encoder.finish(),
            .bzip2 => |*encoder| encoder.finish(),
            .zstd => |*encoder| encoder.finish(),
            .lzma => |*encoder| encoder.finish(),
            .xz => |*encoder| encoder.finish(),
            .ppmd => |*encoder| encoder.finish(),
            .reduce => |*encoder| encoder.finish(),
            .shrink => |*encoder| encoder.finish(),
        }
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            .stored => error.InvalidBlockPlan,
            .deflate => |*encoder| encoder.step(input, output),
            .deflate64 => |*encoder| encoder.step(input, output),
            .dcl_implode => |*encoder| encoder.step(input, output),
            .implode => |*encoder| encoder.step(input, output),
            .bzip2 => |*encoder| encoder.step(input, output),
            .zstd => |*encoder| encoder.step(input, output),
            .lzma => |*encoder| encoder.step(input, output),
            .xz => |*encoder| encoder.step(input, output),
            .ppmd => |*encoder| encoder.step(input, output),
            .reduce => |*encoder| encoder.step(input, output),
            .shrink => |*encoder| encoder.step(input, output),
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
        .deflate64 => {
            if (options.deflate64.block_len == 0 or
                options.deflate64.block_len > std.math.maxInt(u16))
                return error.InvalidBlockPlan;
            try validateExpectedSize(expected_size, options.deflate64.max_input_len);
        },
        .dcl_implode => {
            if (options.dcl_implode.max_chain == 0)
                return error.InvalidDclOptions;
            try validateExpectedSize(expected_size, options.dcl_implode.max_input_len);
        },
        .implode => {
            if (options.implode.max_chain == 0)
                return error.InvalidImplodeOptions;
            try validateExpectedSize(expected_size, options.implode.max_input_len);
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
        .ppmd => try ppmd_codec.validateOptions(options.ppmd, expected_size),
        .reduce_1, .reduce_2, .reduce_3, .reduce_4 => {
            try reduce_encoder.Encoder.validateOptions(options.reduce);
            try validateExpectedSize(expected_size, options.reduce.max_input_len);
        },
        .shrink => {
            if (options.shrink.max_pending_output_len == 0)
                return error.OutputLimitExceeded;
            try validateExpectedSize(expected_size, options.shrink.max_input_len);
        },
        else => return error.UnsupportedZipCompressionMethod,
    }
}

pub fn inputLimit(method: CompressionMethod, options: Options) ?usize {
    return switch (method) {
        .deflate => options.deflate.max_input_len,
        .deflate64 => options.deflate64.max_input_len,
        .dcl_implode => options.dcl_implode.max_input_len,
        .implode => options.implode.max_input_len,
        .bzip2 => options.bzip2.max_input_len,
        .zstandard_legacy, .zstandard => std.math.maxInt(usize),
        .lzma => options.lzma.max_input_len,
        .xz => options.xz.max_input_len,
        .ppmd => options.ppmd.max_input_len,
        .reduce_1, .reduce_2, .reduce_3, .reduce_4 => options.reduce.max_input_len,
        .shrink => options.shrink.max_input_len,
        else => null,
    };
}

pub fn zipFlags(state: *const State) u16 {
    return switch (state.*) {
        .lzma => 1 << 1,
        .implode => |*encoder| encoder.flags(),
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

fn reduceFactor(method: CompressionMethod) ?reduce.Factor {
    return switch (method) {
        .reduce_1 => .factor_1,
        .reduce_2 => .factor_2,
        .reduce_3 => .factor_3,
        .reduce_4 => .factor_4,
        else => null,
    };
}
