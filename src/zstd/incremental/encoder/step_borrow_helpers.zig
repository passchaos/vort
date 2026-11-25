const std = @import("std");

pub const a = std.testing.allocator;

pub fn options(comptime Z: type) Z.NativeFrameOptions {
    return .{ .include_content_size = false, .selection = .raw_or_rle, .content_checksum = false, .block_size_max = 128 };
}

pub fn rejected(encoder: anytype, input: []const u8, output: []u8, directive: bool) !void {
    var regions: [11][]const u8 = @splat(&.{});
    regions[0] = std.mem.asBytes(encoder);
    regions[1] = input;
    regions[2] = output;
    if (comptime @hasField(@TypeOf(encoder.*), "owner")) {
        regions[3] = std.mem.asBytes(encoder.owner);
        regions[4] = std.mem.asBytes(encoder.owner.control);
        regions[5] = std.mem.asBytes(encoder.owner.queue);
        regions[6] = std.mem.sliceAsBytes(encoder.owner.queue.jobs);
        regions[7] = std.mem.sliceAsBytes(encoder.owner.queue.workers);
        if (encoder.owner.options.frame.memory_profile) |profile| regions[8] = std.mem.asBytes(profile);
        if (encoder.owner.options.frame.control_profile) |profile| regions[9] = std.mem.asBytes(profile);
        if (encoder.owner.options.parallel.profile) |profile| regions[10] = std.mem.asBytes(profile);
    } else {
        if (encoder.options.memory_profile) |profile| regions[8] = std.mem.asBytes(profile);
        if (encoder.options.control_profile) |profile| regions[9] = std.mem.asBytes(profile);
        if (encoder.allocation.lease) |lease| {
            if (lease.state) |state| regions[3] = std.mem.asBytes(state);
        }
    }
    var saved: [regions.len][]u8 = @splat(&.{});
    defer for (saved) |bytes| a.free(bytes);
    for (regions, &saved) |region, *bytes| bytes.* = try a.dupe(u8, region);
    if (directive)
        try std.testing.expectError(error.InvalidBlockPlan, encoder.stepWithDirective(input, output, .end))
    else
        try std.testing.expectError(error.InvalidBlockPlan, encoder.step(input, output));
    for (regions, saved) |region, bytes| try std.testing.expectEqualSlices(u8, bytes, region);
}

pub fn ownedList(encoder: anytype, list: anytype) !void {
    try std.testing.expect(list.capacity > list.items.len);
    const bytes = std.mem.sliceAsBytes(list.allocatedSlice());
    @memset(bytes, 0x83);
    const spare = bytes[bytes.len - 1 ..];
    try rejected(encoder, spare, &.{}, false);
    try rejected(encoder, "", spare, true);
}

pub fn roundTrip(comptime Z: type, encoder: anytype, input: []const u8, dictionary: ?Z.NativeDictionary) !void {
    var frame: std.ArrayList(u8) = .empty;
    defer frame.deinit(a);
    var consumed: usize = 0;
    for (0..4096) |_| {
        var output: [19]u8 = undefined;
        const step = try encoder.stepWithDirective(input[consumed..], &output, .end);
        consumed += step.progress.input_read;
        try frame.appendSlice(a, output[0..step.progress.output_written]);
        if (step.status == .done) break;
    } else return error.TestUnexpectedResult;
    try std.testing.expectEqual(input.len, consumed);
    const decoded = try Z.decodeFrameAllocWithOptions(a, frame.items, .{ .dictionary = dictionary });
    defer a.free(decoded);
    try std.testing.expectEqualSlices(u8, input, decoded);
}
