const std = @import("std");
const api = @import("root.zig");
const bits = @import("bitstream.zig");

fn make(comptime stored: bool, allocator: std.mem.Allocator) ![]u8 {
    var writer: bits.BitWriter = .{};
    defer writer.deinit(allocator);
    try writer.writeBits(allocator, if (stored) 1 else 3, 3);
    if (stored) {
        try writer.alignToByte(allocator);
        try writer.writeBits(allocator, 65535, 16);
        try writer.writeBits(allocator, 0, 16);
    }
    for (0..65535) |_| try writer.writeBits(allocator, if (stored) 'A' else 0x8e, 8);
    if (!stored) try writer.writeBits(allocator, 0, 7);
    return writer.toOwnedSlice(allocator);
}

pub fn main() !void {
    inline for (.{ true, false }) |stored| {
        const raw = try make(stored, std.heap.page_allocator);
        defer std.heap.page_allocator.free(raw);
        var arena_bytes: [1024]u8 = undefined;
        var arena = std.heap.FixedBufferAllocator.init(&arena_bytes);
        var limited = std.testing.FailingAllocator.init(arena.allocator(), .{});
        if (api.puffAndroidDeflatePaddedAlloc(limited.allocator(), raw, 0, raw.len * 8, 16)) |result| {
            defer limited.allocator().free(result.bytes);
            std.debug.print("stored={} FBA1024 accepted={}\n", .{ stored, result.bytes.len });
        } else |err| {
            std.debug.print("stored={} FBA1024 error={s} allocated={d} freed={d}\n", .{ stored, @errorName(err), limited.allocated_bytes, limited.freed_bytes });
        }
        var heap = std.testing.FailingAllocator.init(std.heap.page_allocator, .{ .resize_fail_index = 0 });
        if (api.puffAndroidDeflatePaddedAlloc(heap.allocator(), raw, 0, raw.len * 8, 16)) |result| {
            defer heap.allocator().free(result.bytes);
            std.debug.print("stored={} heap accepted={}\n", .{ stored, result.bytes.len });
        } else |err| {
            std.debug.print("stored={} heap error={s} allocated={d} freed={d} allocations={d}\n", .{ stored, @errorName(err), heap.allocated_bytes, heap.freed_bytes, heap.allocations });
        }
    }
}
