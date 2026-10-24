const std = @import("std");
const alias = @import("alias.zig");
const shared = @import("../../shared_dictionary.zig");
const serialized = @import("../../serialized_dictionary.zig");
const working = @import("../../../io/working_allocator.zig");

const encoded = [_]u8{ 0x91, 0, 3, 'r', 'a', 'w', 0, 0 };

test "Brotli HQ alias snapshot leaves unaliased borrows allocation free" {
    var target: [32]u8 = @splat(0xaa);
    const view = try serialized.parse(&encoded);
    const raw = [_][]const u8{ "prefix", "" };
    const chunks = [_][]const u8{ "first", "", "second" };
    const dictionary = shared.Dictionary{ .raw_prefixes = &raw, .serialized = &view };
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    try std.testing.expectEqual(@as(usize, 0), try alias.requiredInputBytes(&target, "input", dictionary));
    try std.testing.expectEqual(@as(usize, 0), try alias.requiredChunksBytes(&target, &chunks, dictionary));
    var input = try alias.Snapshot.initInput(failing.allocator(), &target, "input", dictionary);
    defer input.deinit();
    var chunked = try alias.Snapshot.initChunks(failing.allocator(), &target, &chunks, dictionary);
    defer chunked.deinit();
    try std.testing.expectEqual(@as(usize, 0), input.ownedBytes());
    try std.testing.expectEqual(@as(usize, 0), chunked.ownedBytes());
    try std.testing.expect(input.getInput().ptr == "input".ptr);
    try std.testing.expect(chunked.getChunks().ptr == &chunks);
    try std.testing.expect(input.getDictionary().raw_prefixes.ptr == &raw);
    try std.testing.expect(input.getDictionary().serialized.? == &view);
    var empty = try alias.Snapshot.initInput(failing.allocator(), &target, target[0..0], .{});
    defer empty.deinit();
    try std.testing.expectEqual(@as(usize, 0), empty.ownedBytes());
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

test "Brotli HQ alias snapshot protects input in unused retained output capacity" {
    const allocator = std.testing.allocator;
    const allocation = try allocator.alloc(u8, 64);
    @memset(allocation, 0);
    @memcpy(allocation[40..48], "borrowed");
    var output: std.ArrayList(u8) = .{ .items = allocation[0..4], .capacity = allocation.len };
    defer output.deinit(allocator);
    var snapshot = try alias.Snapshot.initInput(allocator, output.items.ptr[0..output.capacity], output.items.ptr[40..48], .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 8), snapshot.ownedBytes());
    output.clearRetainingCapacity();
    try output.ensureTotalCapacity(allocator, 1024);
    try output.appendSlice(allocator, "new encoded output");
    try std.testing.expectEqualStrings("borrowed", snapshot.getInput());
}

test "Brotli HQ alias snapshot protects chunk bytes and aliased outer descriptors" {
    var target: [128]u8 align(@alignOf([]const u8)) = @splat(0);
    const chunks: *[3][]const u8 = @ptrCast(&target);
    @memcpy(target[80..84], "tail");
    chunks.* = .{ "external", "", target[80..84] };
    var snapshot = try alias.Snapshot.initChunks(std.testing.allocator, &target, chunks, .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(3 * @sizeOf([]const u8) + 4, snapshot.ownedBytes());
    try std.testing.expectEqual(snapshot.ownedBytes(), try alias.requiredChunksBytes(&target, chunks, .{}));
    @memset(&target, 0xa5);
    try std.testing.expectEqualStrings("external", snapshot.getChunks()[0]);
    try std.testing.expectEqualStrings("", snapshot.getChunks()[1]);
    try std.testing.expectEqualStrings("tail", snapshot.getChunks()[2]);
    try std.testing.expect(snapshot.getChunks()[0].ptr == "external".ptr);
}

test "Brotli HQ alias snapshot copies only descriptors when chunk bytes are external" {
    var target: [2][]const u8 = .{ "first", "second" };
    var snapshot = try alias.Snapshot.initChunks(std.testing.allocator, std.mem.asBytes(&target), &target, .{});
    defer snapshot.deinit();
    try std.testing.expectEqual(@sizeOf(@TypeOf(target)), snapshot.ownedBytes());
    target = .{ "changed", "changed" };
    try std.testing.expectEqualStrings("first", snapshot.getChunks()[0]);
    try std.testing.expectEqualStrings("second", snapshot.getChunks()[1]);
}

test "Brotli HQ alias snapshot protects RAW bytes and their outer descriptors" {
    var target: [128]u8 align(@alignOf([]const u8)) = @splat(0);
    const raw: *[2][]const u8 = @ptrCast(&target);
    @memcpy(target[80..83], "raw");
    raw.* = .{ target[80..83], "external" };
    var snapshot = try alias.Snapshot.initInput(std.testing.allocator, &target, "input", .{ .raw_prefixes = raw });
    defer snapshot.deinit();
    try std.testing.expectEqual(2 * @sizeOf([]const u8) + 3, snapshot.ownedBytes());
    @memset(&target, 0xa5);
    try std.testing.expectEqualStrings("raw", snapshot.getDictionary().raw_prefixes[0]);
    try std.testing.expectEqualStrings("external", snapshot.getDictionary().raw_prefixes[1]);
    try std.testing.expect(snapshot.getDictionary().raw_prefixes[1].ptr == "external".ptr);
}

test "Brotli HQ alias snapshot protects RAW bytes with external descriptors" {
    var target: [3]u8 = .{ 'r', 'a', 'w' };
    const raw = [_][]const u8{&target};
    var snapshot = try alias.Snapshot.initInput(std.testing.allocator, &target, "input", .{ .raw_prefixes = &raw });
    defer snapshot.deinit();
    @memset(&target, 0xa5);
    try std.testing.expectEqualStrings("raw", snapshot.getDictionary().raw_prefixes[0]);
    try std.testing.expectEqual(@sizeOf([]const u8) + 3, snapshot.ownedBytes());
}

test "Brotli HQ alias snapshot reparses copied serialized backing" {
    var target = encoded;
    const view = try serialized.parse(&target);
    var snapshot = try alias.Snapshot.initInput(std.testing.allocator, &target, "input", .{ .serialized = &view });
    defer snapshot.deinit();
    try std.testing.expectEqual(encoded.len + @sizeOf(serialized.Dictionary), snapshot.ownedBytes());
    @memset(&target, 0xa5);
    try std.testing.expectEqualSlices(u8, &encoded, snapshot.getDictionary().serialized.?.encoded);
    try std.testing.expectEqualStrings("raw", snapshot.getDictionary().serialized.?.raw_prefix);
    try std.testing.expect(snapshot.getDictionary().serialized.? != &view);
}

test "Brotli HQ alias snapshot owns an aliased serialized view and survives owner movement" {
    var view = try serialized.parse(&encoded);
    var snapshot = try alias.Snapshot.initInput(std.testing.allocator, std.mem.asBytes(&view), "input", .{ .serialized = &view });
    const stable = snapshot.getDictionary().serialized.?;
    var moved = snapshot;
    snapshot = undefined;
    defer moved.deinit();
    @memset(std.mem.asBytes(&view), 0xa5);
    try std.testing.expectEqual(@sizeOf(serialized.Dictionary), moved.ownedBytes());
    try std.testing.expect(moved.getDictionary().serialized.? == stable);
    try std.testing.expect(moved.getDictionary().serialized.?.encoded.ptr == &encoded);
    try std.testing.expectEqualStrings("raw", moved.getDictionary().serialized.?.raw_prefix);
}

test "Brotli HQ alias snapshot protects serialized backing and view in one output allocation" {
    const size = @sizeOf(serialized.Dictionary);
    var target: [size + encoded.len]u8 align(@alignOf(serialized.Dictionary)) = @splat(0);
    const view: *serialized.Dictionary = @ptrCast(&target);
    @memcpy(target[size..], &encoded);
    view.* = try serialized.parse(target[size..]);
    var snapshot = try alias.Snapshot.initInput(std.testing.allocator, &target, "input", .{ .serialized = view });
    defer snapshot.deinit();
    @memset(&target, 0xa5);
    try std.testing.expectEqualSlices(u8, &encoded, snapshot.getDictionary().serialized.?.encoded);
    try std.testing.expectEqualStrings("raw", snapshot.getDictionary().serialized.?.raw_prefix);
}

test "Brotli HQ alias snapshot releases every failed allocation before output mutation" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCase, .{false});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, allocationCase, .{true});
}

fn allocationCase(allocator: std.mem.Allocator, chunked: bool) !void {
    var target: [256]u8 align(@alignOf([]const u8)) = @splat(0);
    const chunks: *[2][]const u8 = @ptrCast(&target);
    const raw: *[2][]const u8 = @ptrCast(@alignCast(&target[2 * @sizeOf([]const u8)]));
    @memcpy(target[128..136], &encoded);
    @memcpy(target[144..147], "raw");
    @memcpy(target[160..168], "borrowed");
    chunks.* = .{ target[160..168], "external" };
    raw.* = .{ target[144..147], "external" };
    const view = try serialized.parse(target[128..136]);
    const dictionary = shared.Dictionary{ .raw_prefixes = raw, .serialized = &view };
    const original = target;
    const required = if (chunked) try alias.requiredChunksBytes(&target, chunks, dictionary) else try alias.requiredInputBytes(&target, target[160..168], dictionary);
    var snapshot = (if (chunked) alias.Snapshot.initChunks(allocator, &target, chunks, dictionary) else alias.Snapshot.initInput(allocator, &target, target[160..168], dictionary)) catch |err| {
        try std.testing.expectEqualSlices(u8, &original, &target);
        try std.testing.expect(@intFromPtr(raw[0].ptr) == @intFromPtr(&target[144]));
        try std.testing.expect(@intFromPtr(chunks[0].ptr) == @intFromPtr(&target[160]));
        try std.testing.expect(@intFromPtr(view.encoded.ptr) == @intFromPtr(&target[128]));
        return err;
    };
    try std.testing.expectEqual(required, snapshot.ownedBytes());
    var moved = snapshot;
    snapshot = undefined;
    defer moved.deinit();
    @memset(&target, 0xa5);
    try std.testing.expectEqualStrings("borrowed", if (chunked) moved.getChunks()[0] else moved.getInput());
    try std.testing.expectEqualStrings("raw", moved.getDictionary().raw_prefixes[0]);
    try std.testing.expectEqualStrings("raw", moved.getDictionary().serialized.?.raw_prefix);
}

test "Brotli HQ alias snapshot prediction matches exact charged live memory" {
    var target = encoded;
    const view = try serialized.parse(&target);
    const dictionary = shared.Dictionary{ .serialized = &view };
    const required = try alias.requiredInputBytes(&target, &target, dictionary);
    var budget = working.WorkingAllocator.init(std.testing.allocator, required);
    var snapshot = try alias.Snapshot.initInput(budget.allocator(), &target, &target, dictionary);
    try std.testing.expectEqual(required, snapshot.ownedBytes());
    try std.testing.expectEqual(required, budget.live);
    try std.testing.expectEqual(required, budget.peak);
    snapshot.deinit();
    try std.testing.expectEqual(@as(usize, 0), budget.live);
    var limited = working.WorkingAllocator.init(std.testing.allocator, required - 1);
    try std.testing.expectError(error.OutOfMemory, alias.Snapshot.initInput(limited.allocator(), &target, &target, dictionary));
    try std.testing.expectEqual(@as(usize, 0), limited.live);
    try std.testing.expect(limited.last_failure_was_limit);
    try std.testing.expectEqualSlices(u8, &encoded, &target);
}

test "Brotli HQ alias snapshot rejects reparsing errors without changing its borrowed view" {
    var view = try serialized.parse(&encoded);
    const invalid = [_]u8{ 0x90, 0, 0, 0, 0 };
    view.encoded = &invalid;
    try std.testing.expectError(error.InvalidMagic, alias.Snapshot.initInput(std.testing.allocator, std.mem.asBytes(&view), "input", .{ .serialized = &view }));
    try std.testing.expect(view.encoded.ptr == &invalid);
    try std.testing.expectEqualStrings("raw", view.raw_prefix);
}

test "Brotli HQ alias snapshot predictions check integer overflow without reading payloads" {
    var target: [1]u8 = .{0};
    const huge = @as([*]const u8, @ptrCast(&target))[0..std.math.maxInt(usize)];
    const chunks = [_][]const u8{huge};
    try std.testing.expectError(error.IntegerOverflow, alias.requiredChunksBytes(&target, &chunks, .{}));
    const invalid_descriptors = @as([*]const []const u8, @ptrCast(@alignCast(&chunks)))[0..std.math.maxInt(usize)];
    try std.testing.expectError(error.IntegerOverflow, alias.requiredChunksBytes(&target, invalid_descriptors, .{}));
    try std.testing.expect(!alias.overlaps(&target, target[0..0]));
}

test "Brotli HQ alias snapshot overlap uses half-open ranges in either order" {
    var memory: [8]u8 = undefined;
    try std.testing.expect(!alias.overlaps(memory[0..4], memory[4..8]));
    try std.testing.expect(alias.overlaps(memory[0..4], memory[3..6]));
    try std.testing.expect(alias.overlaps(memory[3..6], memory[0..4]));
    const near_end: [*]const u8 = @ptrFromInt(std.math.maxInt(usize) - 1);
    const last: [*]const u8 = @ptrFromInt(std.math.maxInt(usize));
    try std.testing.expect(alias.overlaps(near_end[0..2], last[0..1]));
}
