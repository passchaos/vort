//! Caller-owned storage for one complete Zstandard compressed block.
//!
//! Sequence and Huffman payloads are reverse bitstreams, so forward input
//! cannot initialize every legal compressed block before its final marker
//! arrives. This binding makes that unavoidable block retention explicit and
//! caller-owned; it does not claim sub-block progressive sequence decoding.
const std = @import("std");
const core = @import("../../core.zig");
const stable = @import("stable_output.zig");

pub const required_len: usize = std.compress.zstd.block_size_max;

pub const Binding = struct {
    bytes: []u8 = &.{},

    pub fn init(storage: []u8) core.Error!Binding {
        if (storage.len < required_len) return error.OutputTooSmall;
        return .{ .bytes = storage[0..required_len] };
    }

    pub fn active(self: Binding) bool {
        return self.bytes.len != 0;
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

test "Zstd compressed workspace requires exactly one maximum block" {
    var storage: [required_len]u8 = undefined;
    const binding = try Binding.init(&storage);
    try std.testing.expect(binding.active());
    try std.testing.expectEqual(required_len, binding.bytes.len);
    try std.testing.expectError(error.OutputTooSmall, Binding.init(storage[0 .. required_len - 1]));
    try std.testing.expectError(error.InvalidBlockPlan, binding.validateSlice(storage[1..2]));
}
