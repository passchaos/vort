const std = @import("std");
const xz = @import("../../xz.zig");
const container = @import("../container.zig");
const writer = @import("../writer.zig");
const block_header = @import("../writer/block_header.zig");
const h = @import("test_helpers.zig");
const a = std.testing.allocator;

test "XZ block sizes independent real packed and plain VLI boundaries" {
    for ([_]usize{ 123, 124, 127, 128, 16379, 16380, 16383, 16384 }) |length| {
        const input = try h.fixture(length);
        defer a.free(input);
        var opts = h.options();
        opts.block_size = 65536;
        opts.check = .crc32;
        const wire = try xz.encodeStoredAlloc(a, input, opts);
        defer a.free(wire);
        const parsed = try h.parse(wire);
        defer parsed.deinit();
        try std.testing.expectEqual(@as(usize, 1), parsed.blocks.len);
        const entry = parsed.blocks[0];
        try std.testing.expectEqual(length + 4, entry.packed_size);
        try std.testing.expectEqual(@as(u64, length), entry.header.unpacked.?.value);
        try std.testing.expectEqual(@as(u64, length + 4), entry.header.packed_size.?.value);
        const plain_width: usize = if (length < 128) 1 else if (length < 16384) 2 else 3;
        const packed_width: usize = if (length + 4 < 128) 1 else if (length + 4 < 16384) 2 else 3;
        try std.testing.expectEqual(plain_width, entry.header.unpacked.?.width);
        try std.testing.expectEqual(packed_width, entry.header.packed_size.?.width);
        try h.checkWire(wire, input, true);
    }
    const empty = try xz.encodeAlloc(a, "", h.options());
    defer a.free(empty);
    const parsed = try h.parse(empty);
    defer parsed.deinit();
    try std.testing.expectEqual(@as(usize, 0), parsed.blocks.len);
    try h.checkWire(empty, "", true);
}

test "XZ block sizes false keeps legacy goldens and true preserves compressed payload bytes" {
    const input = h.legacy.legacyPlain();
    const golden = h.legacy.hexBytes(h.legacy.xz_greedy_hex);
    const false_wire = try xz.encodeAlloc(a, &input, .{ .include_block_sizes = false });
    defer a.free(false_wire);
    try std.testing.expectEqualSlices(u8, &golden, false_wire);
    const true_wire = try xz.encodeAlloc(a, &input, .{ .include_block_sizes = true });
    defer a.free(true_wire);
    const before = try h.parse(false_wire);
    defer before.deinit();
    const after = try h.parse(true_wire);
    defer after.deinit();
    try std.testing.expectEqual(before.blocks.len, after.blocks.len);
    for (before.blocks, after.blocks) |old, current| {
        try std.testing.expectEqualSlices(u8, false_wire[old.header.end..old.data_end], true_wire[current.header.end..current.data_end]);
        try std.testing.expect(current.compressed != 0);
        try std.testing.expect(current.packed_size != current.plain);
    }
    try h.checkWire(false_wire, &input, false);
    try h.checkWire(true_wire, &input, true);
}

test "XZ block sizes checks parser filter chain serial parallel and incremental wire agree" {
    const input = try h.fixture(1025);
    defer a.free(input);
    const chain = [_]xz.Filter{ xz.Filter.x86(7), try xz.Filter.delta(4) };
    for ([_]xz.Check{ .none, .crc32, .crc64, .sha256 }) |check| for ([_]xz.Parser{ .literal_only, .greedy, .lazy, .fast, .normal }) |parser| {
        var opts = h.options();
        opts.check = check;
        opts.parser = parser;
        opts.filters = &chain;
        if (parser == .normal) opts.match_options.?.finder = .bt4;
        try h.parity(.compressed, input, opts);
    };
    try h.parity(.stored, input, h.options());
    try h.parity(.lazy, input, h.options());
}

test "XZ block sizes all nine filters and twenty presets preserve complete wire" {
    const input = try h.fixture(513);
    defer a.free(input);
    const filters = [_]xz.Filter{ try xz.Filter.delta(4), xz.Filter.x86(4), try xz.Filter.powerpc(4), try xz.Filter.ia64(16), try xz.Filter.arm(4), try xz.Filter.armThumb(2), try xz.Filter.sparc(4), try xz.Filter.arm64(4), try xz.Filter.riscv(2) };
    for (filters) |filter| {
        var opts = h.options();
        opts.filters = &.{filter};
        try h.parity(.stored, input, opts);
    }
    for (0..10) |level| for ([_]bool{ false, true }) |extreme| {
        var opts = try xz.EncodeOptions.fromPreset(@intCast(level), extreme);
        opts.block_size = 128;
        opts.chunk_size = 128;
        opts.include_block_sizes = true;
        try h.parity(.compressed, input, opts);
    };
}

test "XZ block sizes header grammar rejects zero packed before allocation and bounds 63 bit VLI" {
    var output = std.ArrayList(u8).fromOwnedSlice(try a.dupe(u8, "prefix"));
    defer output.deinit(a);
    var denied = std.testing.FailingAllocator.init(a, .{ .fail_index = 0 });
    try std.testing.expectError(error.InvalidBlockPlan, block_header.append(denied.allocator(), &output, &.{}, 0, .{ .compressed_size = 0, .uncompressed_size = 0 }));
    try std.testing.expectEqual(@as(usize, 0), denied.alloc_index);
    try std.testing.expectEqualStrings("prefix", output.items);
    const max = (@as(u64, 1) << 63) - 1;
    _ = try block_header.append(a, &output, &.{}, 0, .{ .compressed_size = max, .uncompressed_size = max });
    const parsed = try h.header(output.items, 6);
    try std.testing.expectEqual(max, parsed.packed_size.?.value);
    try std.testing.expectEqual(max, parsed.unpacked.?.value);
    try std.testing.expectEqual(@as(usize, 9), parsed.packed_size.?.width);
    try std.testing.expectEqual(@as(usize, 9), parsed.unpacked.?.width);
    const old = try a.dupe(u8, output.items);
    defer a.free(old);
    try std.testing.expectError(error.IntegerOverflow, block_header.append(a, &output, &.{}, 0, .{ .compressed_size = max + 1, .uncompressed_size = 0 }));
    try std.testing.expectEqualSlices(u8, old, output.items);
    try std.testing.expectError(error.IntegerOverflow, block_header.append(a, &output, &.{}, 0, .{ .compressed_size = 1, .uncompressed_size = std.math.maxInt(u64) }));
    try std.testing.expectEqualSlices(u8, old, output.items);
    var zero: std.ArrayList(u8) = .empty;
    defer zero.deinit(a);
    _ = try block_header.append(a, &zero, &.{}, 0, .{ .compressed_size = 1, .uncompressed_size = 0 });
    try std.testing.expectEqual(@as(?u64, 0), (try container.parseBlockHeader(zero.items, 0)).unpacked_size);
}

test "XZ block sizes direct appendBlock protects initialized spare aliases before any mutation" {
    const input = h.plain[0..32];
    for ([_]bool{ false, true }) |sizes| for ([_]writer.PayloadEncoding{ .stored, .compressed }) |encoding| {
        var heap = std.testing.FailingAllocator.init(a, .{ .resize_fail_index = 0 });
        const allocation = try heap.allocator().alloc(u8, 48);
        @memset(allocation, 0xa5);
        @memcpy(allocation[16..], input);
        var output = std.ArrayList(u8).fromOwnedSlice(allocation);
        output.items.len = 8; // Retain initialized bytes beyond logical items.
        var alive = true;
        defer if (alive) output.deinit(heap.allocator());
        const original = try a.dupe(u8, allocation);
        defer a.free(original);
        const borrowed = output.allocatedSlice()[16..48];
        var opts = h.options();
        opts.include_block_sizes = sizes;
        opts.check = .sha256;
        heap.fail_index = heap.alloc_index;
        try std.testing.expectError(error.OutOfMemory, writer.appendBlock(heap.allocator(), &output, borrowed, opts, encoding));
        try std.testing.expectEqual(@as(usize, 8), output.items.len);
        try std.testing.expectEqual(allocation.ptr, output.items.ptr);
        try std.testing.expectEqualSlices(u8, original, output.allocatedSlice());
        heap.fail_index = std.math.maxInt(usize);
        const record = try writer.appendBlock(heap.allocator(), &output, borrowed, opts, encoding);
        try std.testing.expect(allocation.ptr != output.items.ptr);
        const parsed = try h.block(output.items, 8, .sha256);
        try std.testing.expectEqual(record.unpadded_size, parsed.unpadded);
        const decoded = try container.decode7zPayloadAllocLimited(a, output.items[parsed.header.end..parsed.data_end], 0, input.len, 4096);
        defer a.free(decoded);
        try std.testing.expectEqualSlices(u8, input, decoded);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(input, &digest, .{});
        try std.testing.expectEqualSlices(u8, &digest, output.items[parsed.check_start..parsed.end]);
        try std.testing.expectEqualSlices(u8, original[0..8], output.items[0..8]);
        output.deinit(heap.allocator());
        alive = false;
        try std.testing.expectEqual(heap.allocated_bytes, heap.freed_bytes);
    };
}
