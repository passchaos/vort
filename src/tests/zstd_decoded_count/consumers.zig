const std = @import("std");
const Count = @import("../../core.zig").StreamCount;
const h = @import("helpers.zig");

pub fn contracts(comptime Z: type) !void {
    const small = try h.smallAlloc(null);
    defer h.a.free(small);
    var denied = std.testing.FailingAllocator.init(h.a, .{ .fail_index = 0 });
    var profile: Z.DecodeMemoryProfile = .{};
    // A wide logical output limit does not weaken the independent heap cap.
    try std.testing.expectError(error.WorkingMemoryLimitExceeded, Z.decodeFrameAllocWithOptions(denied.allocator(), small, .{ .max_output_len = h.boundary + 3, .max_total_working_memory = 0, .memory_profile = &profile }));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expectEqual(@as(usize, 0), profile.peak_requested_bytes);
    profile.reset();
    try std.testing.expectError(error.OutputLimitExceeded, Z.decodeFrameAllocWithOptions(denied.allocator(), small, .{ .max_output_len = 2, .max_total_working_memory = std.math.maxInt(usize), .memory_profile = &profile }));
    try std.testing.expect(!profile.available);
    if (@bitSizeOf(usize) >= 64) return;

    const expected: Count = h.boundary + 3;
    const wire = try h.wideAlloc(.compressed, expected, null);
    defer h.a.free(wire);
    const options: Z.FrameDecodeOptions = .{ .max_output_len = expected, .expected_output_len = expected, .memory_profile = &profile };
    var output: [17]u8 = @splat(0xa5);
    try std.testing.expectError(error.IntegerOverflow, Z.decodeFrameAllocWithOptions(denied.allocator(), wire, options));
    try std.testing.expectError(error.IntegerOverflow, Z.decodeFrameIntoWithOptions(denied.allocator(), wire, &output, options));
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(h.a);
    try out.appendSlice(h.a, "caller");
    const pointer = out.items.ptr;
    const capacity = out.capacity;
    try std.testing.expectError(error.IntegerOverflow, Z.decodeFrameAppendWithOptions(denied.allocator(), &out, wire, options));
    try std.testing.expectError(error.IntegerOverflow, Z.decodeNativeFrameAppend(denied.allocator(), &out, wire));
    var decoder = Z.NativeFrameDecoder.init(denied.allocator());
    defer decoder.deinit();
    try std.testing.expectError(error.IntegerOverflow, decoder.decodeAllocWithOptions(wire, options));
    try std.testing.expectError(error.IntegerOverflow, decoder.decodeIntoSliceWithOptions(wire, &output, options));
    try std.testing.expectError(error.IntegerOverflow, decoder.decodeAppendWithOptions(&out, wire, options));
    try std.testing.expectError(error.IntegerOverflow, decoder.decodeScratchWithOptions(wire, options));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expect(!profile.available);
    try std.testing.expect(!decoder.memorySnapshot().available);
    try std.testing.expectEqual(pointer, out.items.ptr);
    try std.testing.expectEqual(capacity, out.capacity);
    try std.testing.expectEqualStrings("caller", out.items);
    for (output) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}
