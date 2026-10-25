//! Independent source fixtures, progress accounting and prefix finalization.
//! The caller supplies Br; this module never imports the codec root.
const std = @import("std");
const core = @import("../core.zig");

pub const anchor_len: usize = 258;

fn bucket(a: u8, b: u8, c: u8) u16 {
    const word = @as(u32, a) | (@as(u32, b) << 8) | (@as(u32, c) << 16);
    return @truncate((word *% 0x9e3779b1) >> 16);
}

/// All anchor trigrams are unique, and no later prefix position has one.
/// The stronger bucket rejection is independent of the production matcher.
pub fn prefixAlloc(allocator: std.mem.Allocator, length: usize) ![]u8 {
    std.debug.assert(length >= anchor_len);
    const bytes = try allocator.alloc(u8, length);
    errdefer allocator.free(bytes);
    var anchor_buckets: [1024]u64 = @splat(0);
    var random: u64 = 0x19bf_75e3_d284_6ca1;
    for (bytes, 0..) |*byte, index| {
        while (true) {
            random ^= random << 13;
            random ^= random >> 7;
            random ^= random << 17;
            const value: u8 = @truncate(random >> 24);
            if (index >= 2) {
                const key: usize = bucket(bytes[index - 2], bytes[index - 1], value);
                const bit = @as(u64, 1) << @as(u6, @intCast(key % 64));
                if ((anchor_buckets[key / 64] & bit) != 0) continue;
                if (index < anchor_len) anchor_buckets[key / 64] |= bit;
            }
            byte.* = value;
            break;
        }
    }
    for (0..anchor_len - 2) |index|
        try std.testing.expect(std.mem.indexOf(u8, bytes[index + 1 ..], bytes[index..][0..3]) == null);
    return bytes;
}

pub fn repeatedAlloc(allocator: std.mem.Allocator, prefix: []const u8, length: usize) ![]u8 {
    std.debug.assert(length <= anchor_len and length <= prefix.len);
    const input = try allocator.alloc(u8, prefix.len + length);
    @memcpy(input[0..prefix.len], prefix);
    @memcpy(input[prefix.len..], prefix[0..length]);
    return input;
}

pub fn untouched(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

fn step(allocator: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), input: []const u8, quota: usize) !core.StepResult {
    std.debug.assert(quota <= 4096);
    var output: [4096]u8 = @splat(0xa5);
    const before = encoder.snapshot();
    const result = try encoder.step(input, output[0..quota]);
    const after = encoder.snapshot();
    try std.testing.expectEqual(@as(core.StreamCount, result.progress.input_read), after.input_read - before.input_read);
    try std.testing.expectEqual(@as(core.StreamCount, result.progress.output_written), after.output_written - before.output_written);
    try untouched(output[result.progress.output_written..]);
    try wire.appendSlice(allocator, output[0..result.progress.output_written]);
    return result;
}

pub fn feed(allocator: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), input: []const u8, input_quota: usize, output_quota: usize) !void {
    std.debug.assert(input_quota != 0 and output_quota != 0);
    var offset: usize = 0;
    for (0..input.len * 4 + 8192) |call| {
        const end = @min(input.len, offset + input_quota);
        const result = try step(allocator, encoder, wire, input[offset..end], if (call % 17 == 0) 0 else output_quota);
        offset += result.progress.input_read;
        if (offset == input.len and result.status == .need_input) return;
        try std.testing.expect(result.status != .done);
    }
    return error.TestUnexpectedResult;
}

pub fn drain(allocator: std.mem.Allocator, encoder: anytype, wire: *std.ArrayList(u8), expected: core.StepResult.Status, quota: usize) !void {
    std.debug.assert(quota != 0);
    for (0..1024 * 1024) |_| {
        const result = try step(allocator, encoder, wire, "", quota);
        try std.testing.expectEqual(@as(usize, 0), result.progress.input_read);
        if (result.status == expected) return;
        try std.testing.expectEqual(.need_output, result.status);
    }
    return error.TestUnexpectedResult;
}

pub fn drive(allocator: std.mem.Allocator, encoder: anytype, input: []const u8) ![]u8 {
    var wire: std.ArrayList(u8) = .empty;
    errdefer wire.deinit(allocator);
    try feed(allocator, encoder, &wire, input, 4093, 4096);
    try encoder.finish();
    try drain(allocator, encoder, &wire, .done, 4096);
    return wire.toOwnedSlice(allocator);
}

pub fn expectHistory(encoder: anytype, committed: []const u8, window_bits: u5, retained: bool) !void {
    const limit = (@as(usize, 1) << window_bits) - 16;
    const length = if (retained) @min(committed.len, limit) else 0;
    try std.testing.expectEqual(length, encoder.codec_state.history.items.len);
    try std.testing.expectEqualSlices(u8, committed[committed.len - length ..], encoder.codec_state.history.items);
}

/// Finalize a flushed prefix using ISLAST/ISLASTEMPTY directly. The reservoir
/// byte was withheld by the encoder; no encoder finalization hook is called.
pub fn sealPrefix(allocator: std.mem.Allocator, encoder: anytype, wire: []const u8) ![]u8 {
    const snapshot = encoder.snapshot();
    try std.testing.expectEqual(@as(usize, 0), snapshot.buffered_input);
    try std.testing.expectEqual(@as(usize, 0), snapshot.pending_output);
    var sealed: std.ArrayList(u8) = .empty;
    errdefer sealed.deinit(allocator);
    try sealed.appendSlice(allocator, wire);
    const bit_index = encoder.codec_state.bit_index;
    if (bit_index == 0) {
        try sealed.append(allocator, 3);
    } else {
        try std.testing.expect(encoder.pending.items.len != 0);
        try std.testing.expectEqual(encoder.pending.items.len - 1, encoder.pending_offset);
        const final = @as(u16, encoder.pending.items[encoder.pending.items.len - 1]) | (@as(u16, 3) << @as(u4, bit_index));
        try sealed.append(allocator, @truncate(final));
        if (bit_index == 7) try sealed.append(allocator, @truncate(final >> 8));
    }
    return sealed.toOwnedSlice(allocator);
}

pub fn checkWire(comptime Br: type, allocator: std.mem.Allocator, wire: []const u8, input: []const u8, window_bits: u5, large: bool) !Br.StreamSummary {
    try std.testing.expect(wire.len >= 2);
    if (large) {
        // Explicit extension marker and WBITS, independent of codec parsing.
        try std.testing.expectEqual(@as(u8, 0x11), wire[0]);
        try std.testing.expectEqual(@as(u8, window_bits), wire[1] & 0x3f);
        try std.testing.expectError(error.CorruptFrame, Br.decodedStreamSize(wire));
    } else {
        try std.testing.expectEqual(@as(u5, 16), window_bits);
        try std.testing.expectEqual(@as(u8, 0), wire[0] & 1);
    }
    const decoded = try Br.decodeStreamAllocExactSizeWithOptions(allocator, wire, input.len, .{ .allow_large_window = large });
    defer allocator.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
    const summary = try Br.summarizeStreamAllocLimitedWithOptions(allocator, wire, input.len, .{ .allow_large_window = large });
    try std.testing.expectEqual(large, summary.large_window);
    try std.testing.expectEqual(window_bits, summary.window_bits);
    try std.testing.expectEqual(input.len, summary.decoded_bytes);
    try std.testing.expect(summary.max_lz77_distance <= (@as(usize, 1) << window_bits) - 16);
    return summary;
}

/// Refuse only a selected retained allocation's growth, including ArrayList's
/// fallback allocate after remap refusal. Other planning work remains admitted.
pub const TargetedGrowthAllocator = struct {
    backing: std.mem.Allocator,
    target: ?[*]u8 = null,
    fallback_len: ?usize = null,
    refused: usize = 0,

    pub fn allocator(self: *@This()) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(raw: *anyopaque, len: usize, alignment: std.mem.Alignment, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.target != null and self.fallback_len == len) {
            self.refused += 1;
            return null;
        }
        return self.backing.rawAlloc(len, alignment, address);
    }
    fn deny(self: *@This(), memory: []u8, len: usize) bool {
        if (self.target == memory.ptr and len > memory.len) {
            self.fallback_len = len;
            return true;
        }
        return false;
    }
    fn resize(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) bool {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.deny(memory, len)) return false;
        return self.backing.rawResize(memory, alignment, len, address);
    }
    fn remap(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, len: usize, address: usize) ?[*]u8 {
        const self: *@This() = @ptrCast(@alignCast(raw));
        if (self.deny(memory, len)) return null;
        return self.backing.rawRemap(memory, alignment, len, address);
    }
    fn free(raw: *anyopaque, memory: []u8, alignment: std.mem.Alignment, address: usize) void {
        const self: *@This() = @ptrCast(@alignCast(raw));
        self.backing.rawFree(memory, alignment, address);
    }
};
