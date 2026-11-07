//! Caller-owned storage for one complete Zstandard compressed block.
//!
//! Sequence and Huffman payloads are reverse bitstreams, so forward input
//! cannot initialize every legal compressed block before its final marker
//! arrives. This binding makes that unavoidable block retention explicit and
//! caller-owned; it does not claim sub-block progressive sequence decoding.
const std = @import("std");
const core = @import("../../core.zig");
const stable = @import("stable_output.zig");

const Count = core.StreamCount;

/// Standard framing can precede a payload smaller than the largest frame
/// header. Keep enough caller storage for magic, descriptor, window,
/// Dictionary_ID and content-size fields even when the admitted window is
/// tiny. Skippable and block headers are shorter.
pub const control_len: usize = 18;
pub const maximum_len: usize = std.compress.zstd.block_size_max;
pub const required_len: usize = maximum_len;

pub fn requiredLenForWindow(max_window_size: Count) usize {
    const payload_len: usize = @intCast(@min(
        max_window_size,
        @as(Count, maximum_len),
    ));
    return @max(control_len, payload_len);
}

pub const Binding = struct {
    bytes: []u8 = &.{},

    pub fn initForWindow(storage: []u8, max_window_size: Count) core.Error!Binding {
        const required = requiredLenForWindow(max_window_size);
        if (storage.len < required) return error.OutputTooSmall;
        return .{ .bytes = storage[0..required] };
    }

    pub fn active(self: Binding) bool {
        return self.bytes.len != 0;
    }

    pub fn capacity(self: Binding) usize {
        return self.bytes.len;
    }

    pub fn clear(self: *Binding) void {
        self.* = .{};
    }

    pub fn validateSlice(self: Binding, other: []const u8) core.Error!void {
        if (!self.active()) return;
        try stable.validateAlias(self.bytes, other);
    }

    pub fn validateIo(self: Binding, input: []const u8, output: []const u8) core.Error!void {
        try self.validateSlice(input);
        try self.validateSlice(output);
    }

    pub fn validateDictionary(self: Binding, dictionary: anytype) core.Error!void {
        try self.validateSlice(dictionary.content);
        if (dictionary.standard_bytes) |bytes| try self.validateSlice(bytes);
        if (dictionary.prepared) |prepared| try self.validateSlice(std.mem.asBytes(prepared));
    }
};

test "Zstd compressed workspace follows the admitted window" {
    try std.testing.expectEqual(@as(usize, control_len), requiredLenForWindow(0));
    try std.testing.expectEqual(@as(usize, 1024), requiredLenForWindow(1024));
    try std.testing.expectEqual(maximum_len, requiredLenForWindow(maximum_len));
    try std.testing.expectEqual(maximum_len, requiredLenForWindow(std.math.maxInt(Count)));
    var storage: [required_len]u8 = undefined;
    const binding = try Binding.initForWindow(&storage, std.math.maxInt(Count));
    try std.testing.expect(binding.active());
    try std.testing.expectEqual(required_len, binding.bytes.len);
    try std.testing.expectError(
        error.OutputTooSmall,
        Binding.initForWindow(storage[0 .. required_len - 1], std.math.maxInt(Count)),
    );
    try std.testing.expectError(error.InvalidBlockPlan, binding.validateSlice(storage[1..2]));

    const small = try Binding.initForWindow(storage[1..][0..1024], 1024);
    try std.testing.expectEqual(@as(usize, 1024), small.capacity());
    try std.testing.expectError(error.InvalidBlockPlan, small.validateSlice(storage[2..3]));
    try small.validateSlice(storage[1025..1026]);
}
