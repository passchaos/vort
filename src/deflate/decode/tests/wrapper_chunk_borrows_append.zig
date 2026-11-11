const std = @import("std");
const testing = std.testing;
const S = @import("wrapper_chunk_borrows_support.zig");

const Mode = enum { plain, options, exact, options_exact, limited, options_limited, concatenated, concatenated_options, concatenated_exact, concatenated_options_exact, concatenated_limited, concatenated_options_limited };

fn append(comptime D: type, comptime mode: Mode, out: *std.ArrayList(u8), chunks: []const []const u8, scratch: []u8) !usize {
    const a = testing.allocator;
    return switch (mode) {
        .plain => D.decodeGzipChunksAppend(a, out, chunks, scratch),
        .options => D.decodeGzipChunksAppendWithOptions(a, out, chunks, scratch, .{}),
        .exact => D.decodeGzipChunksAppendExactSize(a, out, chunks, scratch, S.plain.len),
        .options_exact => D.decodeGzipChunksAppendWithOptionsExactSize(a, out, chunks, scratch, .{}, S.plain.len),
        .limited => D.decodeGzipChunksAppendLimited(a, out, chunks, scratch, 128),
        .options_limited => D.decodeGzipChunksAppendWithOptionsLimited(a, out, chunks, scratch, .{}, 128),
        .concatenated => D.decodeGzipConcatenatedChunksAppend(a, out, chunks, scratch),
        .concatenated_options => D.decodeGzipConcatenatedChunksAppendWithOptions(a, out, chunks, scratch, .{}),
        .concatenated_exact => D.decodeGzipConcatenatedChunksAppendExactSize(a, out, chunks, scratch, S.plain.len),
        .concatenated_options_exact => D.decodeGzipConcatenatedChunksAppendWithOptionsExactSize(a, out, chunks, scratch, .{}, S.plain.len),
        .concatenated_limited => D.decodeGzipConcatenatedChunksAppendLimited(a, out, chunks, scratch, 128),
        .concatenated_options_limited => D.decodeGzipConcatenatedChunksAppendWithOptionsLimited(a, out, chunks, scratch, .{}, 128),
    };
}

fn alloc(comptime D: type, comptime mode: Mode, chunks: []const []const u8, scratch: []u8) ![]u8 {
    const a = testing.allocator;
    return switch (mode) {
        .plain => D.decodeGzipChunksAlloc(a, chunks, scratch),
        .options => D.decodeGzipChunksAllocWithOptions(a, chunks, scratch, .{}),
        .exact => D.decodeGzipChunksAllocExactSize(a, chunks, scratch, S.plain.len),
        .options_exact => D.decodeGzipChunksAllocWithOptionsExactSize(a, chunks, scratch, .{}, S.plain.len),
        .limited => D.decodeGzipChunksAllocLimited(a, chunks, scratch, 128),
        .options_limited => D.decodeGzipChunksAllocWithOptionsLimited(a, chunks, scratch, .{}, 128),
        .concatenated => D.decodeGzipConcatenatedChunksAlloc(a, chunks, scratch),
        .concatenated_options => D.decodeGzipConcatenatedChunksAllocWithOptions(a, chunks, scratch, .{}),
        .concatenated_exact => D.decodeGzipConcatenatedChunksAllocExactSize(a, chunks, scratch, S.plain.len),
        .concatenated_options_exact => D.decodeGzipConcatenatedChunksAllocWithOptionsExactSize(a, chunks, scratch, .{}, S.plain.len),
        .concatenated_limited => D.decodeGzipConcatenatedChunksAllocLimited(a, chunks, scratch, 128),
        .concatenated_options_limited => D.decodeGzipConcatenatedChunksAllocWithOptionsLimited(a, chunks, scratch, .{}, 128),
    };
}

pub fn contracts(comptime D: type) !void {
    const wire = try S.encode(D, .gzip);
    defer testing.allocator.free(wire);
    const chunks = S.split(wire);
    inline for (comptime std.meta.tags(Mode)) |mode| {
        errdefer std.debug.print("gzip append/alloc chunk borrow mode: {s}\n", .{@tagName(mode)});
        var out: std.ArrayList(u8) = .empty;
        defer out.deinit(testing.allocator);
        try out.ensureTotalCapacity(testing.allocator, 128);
        @memset(out.allocatedSlice(), 0xa5);
        try out.append(testing.allocator, '!');
        const before = try testing.allocator.dupe(u8, out.allocatedSlice());
        defer testing.allocator.free(before);
        const object_before = S.copyBytes(std.ArrayList(u8), &out);
        // Empty capacity after the live prefix is still part of the output borrow.
        try testing.expectError(error.InvalidBlockPlan, append(D, mode, &out, &chunks, out.allocatedSlice()[16..]));
        try testing.expectEqualSlices(u8, before, out.allocatedSlice());
        try testing.expectEqualSlices(u8, &object_before, std.mem.asBytes(&out));
        var independent: [80]u8 = undefined;
        try testing.expectEqual(S.plain.len, try append(D, mode, &out, &chunks, &independent));
        try testing.expectEqualSlices(u8, "!" ++ S.plain, out.items);
        out.shrinkRetainingCapacity(1);
        const single_external = [_][]const u8{wire};
        // With one source chunk, even scratch inside the full list allocation is unused.
        try testing.expectEqual(S.plain.len, try append(D, mode, &out, &single_external, out.allocatedSlice()));
        try testing.expectEqualSlices(u8, "!" ++ S.plain, out.items);
        out.shrinkRetainingCapacity(1);
        @memcpy(out.allocatedSlice()[32..][0..wire.len], wire);
        const single_inside_output = [_][]const u8{out.allocatedSlice()[32..][0..wire.len]};
        // Staged append consumes a borrowed source before touching output capacity.
        try testing.expectEqual(S.plain.len, try append(D, mode, &out, &single_inside_output, &.{}));
        try testing.expectEqualSlices(u8, "!" ++ S.plain, out.items);
        try testing.expectEqualSlices(u8, wire, out.allocatedSlice()[32..][0..wire.len]);
        out.shrinkRetainingCapacity(1);
        const identity_in_output = S.split(out.allocatedSlice()[32..][0..wire.len]);
        // Exact packed identity has no join writes, so the staged path is safe too.
        try testing.expectEqual(S.plain.len, try append(D, mode, &out, &identity_in_output, out.allocatedSlice()[32..]));
        try testing.expectEqualSlices(u8, "!" ++ S.plain, out.items);

        // A real, valid list object located inside the destination must survive.
        const Holder = struct { out: std.ArrayList(u8), tail: [96]u8 };
        var holder: Holder = undefined;
        @memset(std.mem.asBytes(&holder), 0xa5);
        holder.out = .empty;
        defer holder.out.deinit(testing.allocator);
        const holder_before = S.copyBytes(Holder, &holder);
        try testing.expectError(error.InvalidBlockPlan, append(D, mode, &holder.out, &chunks, std.mem.asBytes(&holder)));
        try testing.expectEqualSlices(u8, &holder_before, std.mem.asBytes(&holder));
        try testing.expectEqual(S.plain.len, try append(D, mode, &holder.out, &chunks, &independent));
        try testing.expectEqualSlices(u8, S.plain, holder.out.items);

        // Allocating variants also admit all sources before they join or allocate.
        var backing: [80]u8 = @splat(0xa5);
        @memcpy(backing[2..][0 .. wire.len - 4], wire[4..]);
        const aliased = [_][]const u8{ wire[0..4], backing[2..][0 .. wire.len - 4] };
        const backing_before = backing;
        try testing.expectError(error.InvalidBlockPlan, alloc(D, mode, &aliased, &backing));
        try testing.expectEqualSlices(u8, &backing_before, &backing);
        const decoded = try alloc(D, mode, &aliased, &independent);
        defer testing.allocator.free(decoded);
        try testing.expectEqualSlices(u8, S.plain, decoded);
        // Single-chunk borrowing makes the aliased scratch entirely unused.
        const single = [_][]const u8{wire};
        const decoded_single = try alloc(D, mode, &single, &.{});
        defer testing.allocator.free(decoded_single);
        try testing.expectEqualSlices(u8, S.plain, decoded_single);
    }
}
