const std = @import("std");
const core = @import("../../core.zig");
const stream = @import("../encoder/static_dictionary_stream.zig");
const Count = core.StreamCount;

/// Every descriptor borrows a real, addressable source. This tests wide
/// admission separately from physically encoding the entire 4 GiB source.
pub fn contracts(comptime B: type) !void {
    const allocator = std.testing.allocator;
    const tile = try allocator.alloc(u8, 1 << 20);
    defer allocator.free(tile);
    @memset(tile, 'R');
    const chunks = try allocator.alloc([]const u8, 4100);
    defer allocator.free(chunks);
    chunks[0] = "";
    for (chunks[1..4097]) |*chunk| chunk.* = tile;
    chunks[4097] = "";
    chunks[4098] = tile[0..17];
    chunks[4099] = "";
    const length: Count = (@as(Count, 1) << 32) + 17;
    const options = B.StaticDictionaryStreamOptions{ .block_len = 4096, .max_input_len = length };
    const capped = B.StaticDictionaryStreamOptions{ .block_len = 4096, .max_input_len = length - 1 };
    const Encoder = B.IncrementalStaticDictionaryStreamEncoder;
    try stream.validateChunks(Encoder, 1 << 24, chunks, options);
    try std.testing.expectError(error.OutputLimitExceeded, stream.validateChunks(Encoder, 1 << 24, chunks, capped));

    // The full public allocation/append routes must pass wide admission and
    // reach their first allocation. Deliberate OOM bounds the physical work.
    try std.testing.expectError(error.OutOfMemory, B.encodePlannedStreamStaticDictionaryChunksWithOptionsAlloc(
        std.testing.failing_allocator,
        chunks,
        options,
    ));
    try std.testing.expectError(error.OutOfMemory, B.encodePlannedStreamStaticDictionaryChunksAlloc(
        std.testing.failing_allocator,
        chunks,
    ));
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    try output.appendSlice(allocator, "retained:");
    const pointer = output.items.ptr;
    const capacity = output.capacity;
    try std.testing.expectError(error.OutOfMemory, B.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(
        std.testing.failing_allocator,
        &output,
        chunks,
        options,
    ));
    try std.testing.expectEqualSlices(u8, "retained:", output.items);
    try std.testing.expectEqual(pointer, output.items.ptr);
    try std.testing.expectEqual(capacity, output.capacity);
    try std.testing.expectError(error.OutputLimitExceeded, B.encodePlannedStreamStaticDictionaryChunksWithOptionsAppend(
        allocator,
        &output,
        chunks,
        capped,
    ));
    try std.testing.expectEqualSlices(u8, "retained:", output.items);
    try std.testing.expectEqual(pointer, output.items.ptr);
    try std.testing.expectEqual(capacity, output.capacity);

    var guard: [128]u8 = @splat(0xa5);
    try std.testing.expectError(error.OutputLimitExceeded, B.encodePlannedStreamStaticDictionaryChunksWithOptionsInto(
        chunks,
        &guard,
        capped,
    ));
    try std.testing.expectEqualSlices(u8, &([_]u8{0xa5} ** 128), &guard);
    var cold = B.StaticDictionaryStreamEncoder.init(std.testing.failing_allocator);
    defer cold.deinit();
    try std.testing.expectError(error.OutOfMemory, cold.encodeChunksScratchWithOptions(chunks, options));

    // A real previous wire warms the reusable state. Limit rejection must
    // precede alias capture, output clearing, and incremental reset.
    var warm = B.StaticDictionaryStreamEncoder.init(allocator);
    defer warm.deinit();
    const small = [_][]const u8{ "quot;", "quot;", "" };
    const prior = try warm.encodeChunksScratch(&small);
    const saved = try allocator.dupe(u8, prior);
    defer allocator.free(saved);
    const warm_pointer = warm.output.items.ptr;
    const warm_capacity = warm.output.capacity;
    const snapshot = warm.incremental.snapshot();
    const retained = warm.retainedCapacity();
    try std.testing.expectError(error.OutputLimitExceeded, warm.encodeChunksScratchWithOptions(chunks, capped));
    try std.testing.expectEqualSlices(u8, saved, warm.output.items);
    try std.testing.expectEqual(warm_pointer, warm.output.items.ptr);
    try std.testing.expectEqual(warm_capacity, warm.output.capacity);
    try std.testing.expectEqual(retained, warm.retainedCapacity());
    try std.testing.expectEqualDeep(snapshot, warm.incremental.snapshot());
}
