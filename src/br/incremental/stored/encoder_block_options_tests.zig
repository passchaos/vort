const std = @import("std");
const generic = @import("encoder.zig");

const HookCodec = struct {
    pub const Error = error{ OutOfMemory, InvalidBlockPlan, IntegerOverflow, TrailingData, OutputLimitExceeded };
    pub const StreamOptions = struct { block_len: usize = 2 };
    pub const State = struct { effective_block_len: usize = 0 };
    pub const max_block_len: usize = 16;
    pub const default_block_len: usize = 0;

    pub fn resolveBlockLen(options: StreamOptions, requested: usize) Error!usize {
        return if (requested == 0) options.block_len else requested;
    }
    pub fn readyOutputLen(_: *const State, pending_len: usize, _: bool) usize {
        return pending_len;
    }
    pub fn writePrefix(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, options: StreamOptions) Error!void {
        try out.append(a, @intCast(options.block_len));
        state.effective_block_len = options.block_len;
    }
    pub fn writePrefixWithBlockLen(a: std.mem.Allocator, out: *std.ArrayList(u8), state: *State, _: StreamOptions, effective: usize) Error!void {
        try out.append(a, @intCast(effective));
        state.effective_block_len = effective;
    }
    pub fn writeBlock(a: std.mem.Allocator, out: *std.ArrayList(u8), _: *State, input: []const u8) Error!void {
        try out.appendSlice(a, input);
    }
    pub fn writeMetadata(a: std.mem.Allocator, out: *std.ArrayList(u8), _: *State, metadata: []const u8) Error!void {
        try out.appendSlice(a, metadata);
    }
    pub fn writeFinal(a: std.mem.Allocator, out: *std.ArrayList(u8), _: *State) Error!void {
        try out.append(a, 0xff);
    }
};

const LegacyCodec = struct {
    pub const Error = HookCodec.Error;
    pub const StreamOptions = HookCodec.StreamOptions;
    pub const State = HookCodec.State;
    pub const max_block_len = HookCodec.max_block_len;
    pub const default_block_len = HookCodec.default_block_len;
    pub const resolveBlockLen = HookCodec.resolveBlockLen;
    pub const readyOutputLen = HookCodec.readyOutputLen;
    pub const writePrefix = HookCodec.writePrefix;
    pub const writeBlock = HookCodec.writeBlock;
    pub const writeMetadata = HookCodec.writeMetadata;
    pub const writeFinal = HookCodec.writeFinal;
};

test "Brotli HQ generic prefix receives the resolved outer block target" {
    const Encoder = generic.Encoder(HookCodec);
    inline for (.{ 0, 6 }) |requested| {
        var encoder = Encoder.initWithOptions(std.testing.allocator, .{ .stream = .{ .block_len = 2 }, .block_len = requested });
        defer encoder.deinit();
        var output: [8]u8 = undefined;
        const step = try encoder.step(&.{}, &output);
        const effective: usize = if (requested == 0) 2 else requested;
        try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
        try std.testing.expectEqual(@as(u8, @intCast(effective)), output[0]);
        try std.testing.expectEqual(effective, encoder.codec_state.effective_block_len);
        try std.testing.expectEqual(@as(usize, 2), encoder.options.stream.block_len);
    }
}

test "Brotli HQ generic prefix preserves codecs without the block target hook" {
    var encoder = generic.Encoder(LegacyCodec).initWithOptions(std.testing.allocator, .{ .stream = .{ .block_len = 2 }, .block_len = 6 });
    defer encoder.deinit();
    var output: [8]u8 = undefined;
    const step = try encoder.step(&.{}, &output);
    try std.testing.expectEqual(@as(usize, 1), step.progress.output_written);
    try std.testing.expectEqual(@as(u8, 2), output[0]);
    try std.testing.expectEqual(@as(usize, 2), encoder.codec_state.effective_block_len);
}
