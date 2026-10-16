//! Adapters that normalize existing incremental decompressor lifecycles.

const std = @import("std");
const core = @import("../../core.zig");
const br = @import("../../br.zig");
const bzip2 = @import("../../bzip2.zig");
const deflate = @import("../../deflate.zig");
const lz4 = @import("../../lz4.zig");
const lz4_legacy = @import("../../lz4_legacy.zig");
const lzf = @import("../../lzf.zig");
const lzip = @import("../../lzip.zig");
const lzma = @import("../../lzma.zig");
const lzop = @import("../../lzop.zig");
const xz = @import("../../xz.zig");
const zstd = @import("../../zstd.zig");

pub const Gzip = struct {
    pub const Options = deflate.GzipIncrementalDecoder.Options;
    pub const Error = deflate.GzipIncrementalDecoder.Error || std.mem.Allocator.Error;
    pub const default_options: Options = .{ .allow_concatenated = true };

    pub const State = struct {
        allocator: std.mem.Allocator,
        history: []u8,
        decoder: deflate.GzipIncrementalDecoder,
    };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
        const history = try allocator.alloc(
            u8,
            deflate.RawDeflateIncrementalFixedLiteralDecoder.required_history_len,
        );
        errdefer allocator.free(history);
        return .{
            .allocator = allocator,
            .history = history,
            .decoder = try deflate.GzipIncrementalDecoder.init(options, history),
        };
    }

    pub fn deinit(state: *State) void {
        state.allocator.free(state.history);
        state.* = undefined;
    }

    pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
        return state.decoder.step(input, output);
    }

    pub fn finish(state: *State) Error!void {
        try state.decoder.finish();
    }
};

fn AllocatorDecoder(
    comptime Decoder: type,
    comptime ErrorType: type,
    comptime fallible_finish: bool,
) type {
    return struct {
        pub const Options = Decoder.Options;
        pub const Error = ErrorType;
        pub const State = Decoder;
        pub const default_options: Options = .{};

        pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
            return Decoder.initWithOptions(allocator, options);
        }

        pub fn deinit(state: *State) void {
            state.deinit();
        }

        pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
            return state.step(input, output);
        }

        pub fn finish(state: *State) Error!void {
            if (comptime fallible_finish) {
                try state.finish();
            } else {
                state.finish();
            }
        }
    };
}

pub const Bzip2 = AllocatorDecoder(bzip2.IncrementalDecoder, bzip2.Error, false);
pub const Brotli = AllocatorDecoder(br.IncrementalStreamDecoder, br.Error, true);
pub const Lzma = AllocatorDecoder(lzma.IncrementalDecoder, lzma.Error, false);
pub const Xz = AllocatorDecoder(xz.IncrementalDecoder, xz.Error, false);
pub const Lz4 = AllocatorDecoder(lz4.NativeIncrementalFrameDecoder, lz4.Error, true);
pub const Lz4Legacy = AllocatorDecoder(lz4_legacy.IncrementalDecoder, lz4_legacy.Error, false);
pub const Lzf = AllocatorDecoder(lzf.IncrementalDecoder, lzf.Error, false);
pub const Lzip = AllocatorDecoder(lzip.IncrementalDecoder, lzip.Error, false);
pub const Zstandard = AllocatorDecoder(zstd.IncrementalFrameDecoder, zstd.Error, true);
pub const Lzop = AllocatorDecoder(lzop.IncrementalDecoder, lzop.Error, true);
