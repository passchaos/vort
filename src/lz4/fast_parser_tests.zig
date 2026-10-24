const std = @import("std");
const parser = @import("fast_parser.zig");
const fast = @import("fast_options.zig");

const RejectEmitter = struct {
    pub fn emitSequence(_: std.mem.Allocator, _: *std.ArrayList(u8), _: []const u8, _: u16, _: usize) parser.Error!void {
        return error.OutputTooSmall;
    }
    pub fn emitLastLiteral(_: std.mem.Allocator, _: *std.ArrayList(u8), _: []const u8) parser.Error!void {
        return error.OutputTooSmall;
    }
};

test "LZ4 fast parser emitter rejection retains inspected skipped and seeded attempt work" {
    var table: [65536]u32 = undefined;
    var bits: [1024]u64 = undefined;
    var chain: [65536]u32 = undefined;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(std.testing.allocator);
    var profile: fast.FastEncodeProfile = .{};
    const options = try (fast.BlockEncodeOptions{ .acceleration = 8, .chain_depth = 0, .profile = &profile }).work();
    const input = "abcdefgh" ** 32;
    try std.testing.expectError(error.OutputTooSmall, parser.encodeLinkedBlockInto(RejectEmitter, std.testing.allocator, &out, "previous bytes", input, &table, &bits, &chain, options));
    try std.testing.expectEqual(@as(usize, 0), out.items.len);
    try std.testing.expectEqual(@as(u64, 1), profile.blocks_attempted);
    try std.testing.expect(profile.positions_inspected > 0 and profile.positions_skipped > 0);
    try std.testing.expectEqual(@as(u64, 0), profile.chain_candidates);
    try std.testing.expectEqual(@as(u64, "previous bytes".len), profile.history_positions_seeded);
    try std.testing.expectEqual(@as(u32, 8), profile.resolved_acceleration);
    try std.testing.expectEqual(@as(u8, 0), profile.resolved_chain_depth);
}

test "LZ4 fast parser reservation failure performs no speculative searches or source reads" {
    var table: [65536]u32 = undefined;
    var bits: [1024]u64 = undefined;
    var chain: [65536]u32 = undefined;
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    var out: std.ArrayList(u8) = .empty;
    var profile: fast.FastEncodeProfile = .{};
    const options = try (fast.BlockEncodeOptions{ .acceleration = 32, .profile = &profile }).work();
    const bytes: [*]const u8 = @ptrFromInt(1);
    try std.testing.expectError(error.OutOfMemory, parser.encodeLinkedBlockInto(RejectEmitter, failing.allocator(), &out, bytes[0..1000], bytes[0..2000], &table, &bits, &chain, options));
    try std.testing.expectEqual(@as(usize, 0), out.items.len);
    try std.testing.expectEqual(@as(u64, 1), profile.blocks_attempted);
    try std.testing.expectEqual(@as(u64, 0), profile.positions_inspected);
    try std.testing.expectEqual(@as(u64, 0), profile.history_positions_seeded);
}
