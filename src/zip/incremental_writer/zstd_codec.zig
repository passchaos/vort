//! ZIP method 20/93 selects serial encoding unless parallel work is explicit.
const std = @import("std");
const core = @import("../../core.zig");
const zstd = @import("../../zstd.zig");
const stream_parallel = @import("../../zstd/incremental_parallel/types.zig");

pub const Options = zstd.NativeFrameOptions;
pub const ParallelOptions = stream_parallel.ParallelOptions;
pub const Error = zstd.Error || stream_parallel.Error;

pub fn resolvedOptions(requested: Options, dictionary: ?zstd.NativeDictionary) Error!Options {
    var resolved = requested;
    if (resolved.format != .standard) return error.InvalidBlockPlan;
    if (dictionary) |preset| {
        if (resolved.dictionary_id != 0 and resolved.dictionary_id != preset.id)
            return error.InvalidBlockPlan;
        resolved.dictionary_id = preset.id;
    } else if (resolved.dictionary_id != 0) return error.InvalidBlockPlan;
    return resolved;
}

pub fn validate(requested: Options, parallel: ?ParallelOptions, dictionary: ?zstd.NativeDictionary, expected: ?core.StreamCount) Error!void {
    var frame = try resolvedOptions(requested, dictionary);
    if (parallel) |policy| {
        frame.include_content_size = expected != null;
        try zstd.NativeIncrementalParallelFrameEncoder.validateOptions(.{ .frame = frame, .parallel = policy }, expected, dictionary);
    } else if (expected) |size| {
        _ = std.math.cast(usize, size) orelse return error.OutputLimitExceeded;
    }
}

/// Both variants own their state. Moving this union transfers ownership; do
/// not use the previous value after the move, and deinit only the new owner.
pub const State = union(enum) {
    serial: zstd.NativeIncrementalFrameEncoder,
    parallel: zstd.NativeIncrementalParallelFrameEncoder,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, requested: Options, parallel: ?ParallelOptions, dictionary: ?zstd.NativeDictionary, expected: ?core.StreamCount) Error!Self {
        var frame = try resolvedOptions(requested, dictionary);
        frame.include_content_size = expected != null;
        if (parallel) |policy| {
            const options: zstd.NativeIncrementalParallelFrameEncoder.Options = .{ .frame = frame, .parallel = policy };
            return .{ .parallel = if (dictionary) |preset|
                if (expected) |size|
                    try zstd.NativeIncrementalParallelFrameEncoder.initExactSizeWithPresetDictionary(allocator, options, size, preset)
                else
                    try zstd.NativeIncrementalParallelFrameEncoder.initWithPresetDictionary(allocator, options, preset)
            else if (expected) |size|
                try zstd.NativeIncrementalParallelFrameEncoder.initExactSize(allocator, options, size)
            else
                try zstd.NativeIncrementalParallelFrameEncoder.init(allocator, options) };
        }
        return .{ .serial = if (dictionary) |preset|
            if (expected) |size|
                try zstd.NativeIncrementalFrameEncoder.initExactSizeWithPresetDictionary(allocator, frame, @intCast(size), preset)
            else
                try zstd.NativeIncrementalFrameEncoder.initWithPresetDictionary(allocator, frame, preset)
        else if (expected) |size|
            try zstd.NativeIncrementalFrameEncoder.initExactSize(allocator, frame, @intCast(size))
        else
            try zstd.NativeIncrementalFrameEncoder.init(allocator, frame) };
    }

    pub fn deinit(self: *Self) void {
        switch (self.*) {
            inline else => |*encoder| encoder.deinit(),
        }
        self.* = undefined;
    }

    pub fn finish(self: *Self) void {
        switch (self.*) {
            inline else => |*encoder| encoder.finish(),
        }
    }

    pub fn step(self: *Self, input: []const u8, output: []u8) Error!core.StepResult {
        return switch (self.*) {
            inline else => |*encoder| encoder.step(input, output),
        };
    }

    pub fn failedProgress(self: *const Self) ?core.Progress {
        return switch (self.*) {
            .serial => null,
            .parallel => |*encoder| encoder.failedProgress(),
        };
    }
};
