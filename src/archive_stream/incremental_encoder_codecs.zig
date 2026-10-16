//! Shared adapters that normalize incremental compressor lifecycles.

const std = @import("std");
const core = @import("../core.zig");
const br = @import("../br.zig");
const bzip2 = @import("../bzip2.zig");
const compress_z = @import("../compress_z.zig");
const deflate = @import("../deflate.zig");
const lz4 = @import("../lz4.zig");
const lz4_legacy = @import("../lz4_legacy.zig");
const lzma = @import("../lzma.zig");
const lzf = @import("../lzf.zig");
const lzip = @import("../lzip.zig");
const lzop = @import("../lzop.zig");
const xz = @import("../xz.zig");
const zstd = @import("../zstd.zig");

pub const Gzip = struct {
    pub const State = deflate.GzipIncrementalBestEncoder;
    pub const Options = State.Options;
    pub const Error = State.Error;
    pub const default_options: Options = .{};

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
        return State.initWithOptions(allocator, options);
    }

    pub fn deinit(state: *State) void {
        state.deinit();
    }

    pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
        return state.step(input, output);
    }

    pub fn finish(state: *State) Error!void {
        state.finish();
    }
};

pub const Bzip2 = FallibleInitVoidFinish(bzip2.IncrementalEncoder, bzip2.Error);

pub const Brotli = struct {
    pub const State = br.IncrementalPlannedStreamEncoder;
    pub const Options = State.Options;
    pub const Error = br.Error;
    pub const default_options: Options = .{};

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
        return State.initWithOptions(allocator, options);
    }

    pub fn deinit(state: *State) void {
        state.deinit();
    }

    pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
        return state.step(input, output);
    }

    pub fn finish(state: *State) Error!void {
        try state.finish();
    }
};

pub const CompressZ = FallibleInitVoidFinish(
    compress_z.IncrementalEncoder,
    compress_z.Error,
);

pub const Lzma = FallibleInitVoidFinish(lzma.IncrementalEncoder, lzma.Error);
pub const Xz = FallibleInitVoidFinish(xz.IncrementalEncoder, xz.Error);

pub const Lz4 = struct {
    pub const State = lz4.NativeIncrementalFrameEncoder;
    pub const Options = lz4.NativeFrameOptions;
    pub const Error = lz4.Error;
    pub const default_options: Options = .{ .include_content_size = false };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
        return State.init(allocator, options);
    }

    pub fn deinit(state: *State) void {
        state.deinit();
    }

    pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
        return state.step(input, output);
    }

    pub fn finish(state: *State) Error!void {
        state.finish();
    }
};

pub const Lz4Legacy = FallibleInitVoidFinish(
    lz4_legacy.IncrementalEncoder,
    lz4_legacy.Error,
);
pub const Lzf = FallibleInitVoidFinish(lzf.IncrementalEncoder, lzf.Error);
pub const Lzip = FallibleInitVoidFinish(lzip.IncrementalEncoder, lzip.Error);

pub const Zstandard = struct {
    pub const State = zstd.NativeIncrementalFrameEncoder;
    pub const Options = zstd.NativeFrameOptions;
    pub const Error = zstd.Error;
    pub const default_options: Options = .{ .include_content_size = false };

    pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
        return State.init(allocator, options);
    }

    pub fn deinit(state: *State) void {
        state.deinit();
    }

    pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
        return state.step(input, output);
    }

    pub fn finish(state: *State) Error!void {
        state.finish();
    }
};

pub const Lzop = FallibleInitVoidFinish(lzop.IncrementalEncoder, lzop.Error);

fn FallibleInitVoidFinish(comptime Encoder: type, comptime ErrorType: type) type {
    return struct {
        pub const State = Encoder;
        pub const Options = Encoder.Options;
        pub const Error = ErrorType;
        pub const default_options: Options = .{};

        pub fn init(allocator: std.mem.Allocator, options: Options) Error!State {
            return State.initWithOptions(allocator, options);
        }

        pub fn deinit(state: *State) void {
            state.deinit();
        }

        pub fn step(state: *State, input: []const u8, output: []u8) Error!core.StepResult {
            return state.step(input, output);
        }

        pub fn finish(state: *State) Error!void {
            state.finish();
        }
    };
}
