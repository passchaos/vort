const std = @import("std");
const core = @import("../core.zig");
const stored_encoder = @import("../deflate/incremental/encoder/stored.zig");

pub const Error = core.Error || std.mem.Allocator.Error;

const Codec = struct {
    pub const Error = incremental_encoder.Error;
    pub const max_block_len: usize = std.math.maxInt(u16);

    pub const State = struct {
        // Required by the shared flush state machine. Deflate64 stored blocks
        // always finish byte-aligned, so this remains zero.
        bit_index: u3 = 0,
    };

    pub fn deinitState(_: *State, _: std.mem.Allocator) void {}

    pub fn resetState(state: *State) void {
        state.* = .{};
    }

    pub fn writeBlock(
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
        _: *State,
        block: []const u8,
        final: bool,
    ) incremental_encoder.Error!void {
        if (block.len > max_block_len) return error.InvalidBlockPlan;
        try out.ensureUnusedCapacity(allocator, block.len + 5);
        out.appendAssumeCapacity(@intFromBool(final));
        var lengths: [4]u8 = undefined;
        const len: u16 = @intCast(block.len);
        std.mem.writeInt(u16, lengths[0..2], len, .little);
        std.mem.writeInt(u16, lengths[2..4], ~len, .little);
        out.appendSliceAssumeCapacity(&lengths);
        out.appendSliceAssumeCapacity(block);
    }

    pub fn writePartialFlush(
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
        state: *State,
    ) incremental_encoder.Error!void {
        try writeBlock(allocator, out, state, "", false);
    }

    pub fn writeSyncFlush(
        allocator: std.mem.Allocator,
        out: *std.ArrayList(u8),
        state: *State,
    ) incremental_encoder.Error!void {
        try writeBlock(allocator, out, state, "", false);
    }
};

const incremental_encoder = @This();
pub const Encoder = stored_encoder.Encoder(Codec);
