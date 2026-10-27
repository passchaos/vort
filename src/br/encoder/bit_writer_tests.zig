const std = @import("std");
const BitWriter = @import("bit_writer.zig").Writer;
const huffman = @import("../../huffman.zig");
const bit_count = @import("../../io/bit_count.zig");
const BitCount = bit_count.BitCount;
const Error = @import("bit_writer.zig").Error;

test "Brotli bit writer uses reserved and bounded capacity" {
    var storage: [2]u8 = undefined;
    var out: std.ArrayList(u8) = .{
        .items = storage[0..0],
        .capacity = storage.len,
    };
    var writer = BitWriter{ .out = &out, .bounded = true };
    try writer.writeBits(std.testing.allocator, 0xabcd, 16);
    try std.testing.expectEqualSlices(u8, &.{ 0xcd, 0xab }, out.items);
    try std.testing.expectError(error.OutOfMemory, writer.writeBits(std.testing.allocator, 1, 1));
}

test "Brotli narrow Huffman bit writer matches the general writer" {
    const values = [_]u16{ 0, 1, 0x5555, 0x7fff };
    for (0..8) |initial_bits| {
        for (1..huffman.max_code_bits + 1) |count| {
            const mask = (@as(u16, 1) << @intCast(count)) - 1;
            for (values) |unmasked| {
                const value = unmasked & mask;
                var general: std.ArrayList(u8) = .empty;
                defer general.deinit(std.testing.allocator);
                var narrow: std.ArrayList(u8) = .empty;
                defer narrow.deinit(std.testing.allocator);

                if (initial_bits != 0) {
                    const initial_byte = @as(u8, 0xa5) & ((@as(u8, 1) << @intCast(initial_bits)) - 1);
                    try general.append(std.testing.allocator, initial_byte);
                    try narrow.append(std.testing.allocator, initial_byte);
                }
                var general_writer = BitWriter{ .out = &general, .bit_index = @intCast(initial_bits) };
                var narrow_writer = BitWriter{ .out = &narrow, .bit_index = @intCast(initial_bits) };
                try general_writer.writeBits(std.testing.allocator, value, @intCast(count));
                try narrow_writer.writeHuffmanBits(std.testing.allocator, value, @intCast(count));

                try std.testing.expectEqual(general_writer.bit_index, narrow_writer.bit_index);
                try std.testing.expectEqualSlices(u8, general.items, narrow.items);
            }
        }
    }
}

test "Brotli narrow Huffman bit writer preserves bounded overflow" {
    var storage = [_]u8{0} ** 2;
    var out: std.ArrayList(u8) = .{
        .items = storage[0..1],
        .capacity = storage.len,
    };
    out.items[0] = 0x7f;
    var writer = BitWriter{ .out = &out, .bit_index = 7, .bounded = true };

    try std.testing.expectError(error.OutOfMemory, writer.writeHuffmanBits(std.testing.allocator, 0x7fff, 15));
}

const ReferenceWriter = struct {
    out: *std.ArrayList(u8),
    bit_index: u3 = 0,
    bounded: bool = false,

    pub fn writeBits(self: *ReferenceWriter, allocator: std.mem.Allocator, value: u64, count: u6) Error!void {
        if (count > 64) return error.CorruptFrame;
        if (count == 0) return;
        var remaining: usize = count;
        var cursor = value;
        while (remaining != 0) {
            if (self.bit_index == 0) try self.appendZeroByte(allocator);
            const available: usize = 8 - @as(usize, self.bit_index);
            const take = @min(remaining, available);
            const mask = (@as(u64, 1) << @intCast(take)) - 1;
            self.out.items[self.out.items.len - 1] |= @as(u8, @intCast(cursor & mask)) << self.bit_index;
            cursor >>= @intCast(take);
            remaining -= take;
            const next = @as(usize, self.bit_index) + take;
            self.bit_index = @intCast(next & 7);
        }
    }

    /// Writes a validated, non-empty Brotli Huffman code. Huffman code widths
    /// are capped at 15 bits, so the code can touch at most three bytes. The
    /// payload encoder has already validated the tree and code width; spelling
    /// out those writes avoids the general bit writer's per-byte loop in its
    /// hottest call sites while preserving the same growth and bounded-output
    /// behavior through `appendZeroByte`.
    pub inline fn writeHuffmanBits(self: *ReferenceWriter, allocator: std.mem.Allocator, value: u16, count: u4) Error!void {
        std.debug.assert(count != 0);
        std.debug.assert(value < (@as(u16, 1) << count));

        if (self.bit_index == 0) try self.appendZeroByte(allocator);
        const shifted = @as(u32, value) << self.bit_index;
        self.out.items[self.out.items.len - 1] |= @truncate(shifted);

        const total_bits = @as(u5, self.bit_index) + @as(u5, count);
        if (total_bits > 8) {
            try self.appendZeroByte(allocator);
            self.out.items[self.out.items.len - 1] = @truncate(shifted >> 8);
            if (total_bits > 16) {
                try self.appendZeroByte(allocator);
                self.out.items[self.out.items.len - 1] = @truncate(shifted >> 16);
            }
        }
        self.bit_index = @truncate(total_bits & 7);
    }

    inline fn appendZeroByte(self: *ReferenceWriter, allocator: std.mem.Allocator) Error!void {
        if (self.out.items.len < self.out.capacity) {
            self.out.appendAssumeCapacity(0);
        } else if (self.bounded) {
            return error.OutOfMemory;
        } else {
            try self.out.append(allocator, 0);
        }
    }

    pub fn alignToByte(self: *ReferenceWriter) void {
        self.bit_index = 0;
    }

    pub fn bitPosition(self: *const ReferenceWriter) BitCount {
        return if (self.bit_index == 0) bit_count.fromBytesAssumeBounded(self.out.items.len) else bit_count.positionAssumeBounded(self.out.items.len - 1, self.bit_index);
    }

    pub fn writeAlignedBytes(self: *ReferenceWriter, allocator: std.mem.Allocator, bytes: []const u8) Error!void {
        if (self.bit_index != 0) return error.CorruptFrame;
        if (self.bounded) {
            try self.out.appendSliceBounded(bytes);
        } else {
            try self.out.appendSlice(allocator, bytes);
        }
    }
};

test "Brotli bit writer bulk matches scalar values offsets and bounded failures" {
    const values = [_]u64{ 0, 1, std.math.maxInt(u64), 0x1357_9bdf_2468_ace0 };
    for (0..8) |offset| {
        for (0..64) |width| {
            for (1..12) |capacity| {
                for (values) |value| {
                    var scalar_storage = [_]u8{0xcc} ** 12;
                    var bulk_storage = scalar_storage;
                    scalar_storage[0] = 0xa5;
                    bulk_storage[0] = 0xa5;
                    var scalar_out: std.ArrayList(u8) = .{ .items = scalar_storage[0..1], .capacity = capacity };
                    var bulk_out: std.ArrayList(u8) = .{ .items = bulk_storage[0..1], .capacity = capacity };
                    var scalar = ReferenceWriter{ .out = &scalar_out, .bit_index = @intCast(offset), .bounded = true };
                    var bulk = BitWriter{ .out = &bulk_out, .bit_index = @intCast(offset), .bounded = true };
                    const expected: ?Error = if (scalar.writeBits(std.testing.allocator, value, @intCast(width))) |_| null else |err| err;
                    const actual: ?Error = if (bulk.writeBits(std.testing.allocator, value, @intCast(width))) |_| null else |err| err;
                    try std.testing.expectEqual(expected, actual);
                    try std.testing.expectEqual(scalar.bit_index, bulk.bit_index);
                    try std.testing.expectEqual(scalar_out.items.len, bulk_out.items.len);
                    try std.testing.expectEqualSlices(u8, &scalar_storage, &bulk_storage);
                }
            }
        }
    }
}

test "Brotli bit writer bulk preserves growth allocation and failure ledgers" {
    for (0..12) |fail_index| {
        var scalar_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var bulk_heap = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = fail_index });
        var scalar_out: std.ArrayList(u8) = .empty;
        var bulk_out: std.ArrayList(u8) = .empty;
        var scalar = ReferenceWriter{ .out = &scalar_out };
        var bulk = BitWriter{ .out = &bulk_out };
        var state: u64 = 0x1234_5678_9abc_def0;
        for (0..2048) |i| {
            state = state *% 6364136223846793005 +% 1;
            const width: u6 = @truncate(state >> 58);
            const expected: ?Error = if (i % 3 == 0)
                (if (scalar.writeBits(scalar_heap.allocator(), state, width)) |_| null else |err| err)
            else
                (if (scalar.writeHuffmanBits(scalar_heap.allocator(), @truncate(state & 0x7fff), 15)) |_| null else |err| err);
            const actual: ?Error = if (i % 3 == 0)
                (if (bulk.writeBits(bulk_heap.allocator(), state, width)) |_| null else |err| err)
            else
                (if (bulk.writeHuffmanBits(bulk_heap.allocator(), @truncate(state & 0x7fff), 15)) |_| null else |err| err);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqual(scalar.bit_index, bulk.bit_index);
            try std.testing.expectEqual(scalar_out.capacity, bulk_out.capacity);
            try std.testing.expectEqualSlices(u8, scalar_out.items, bulk_out.items);
            if (expected != null) break;
        }
        scalar_out.deinit(scalar_heap.allocator());
        bulk_out.deinit(bulk_heap.allocator());
        try std.testing.expectEqual(scalar_heap.allocated_bytes, bulk_heap.allocated_bytes);
        try std.testing.expectEqual(scalar_heap.freed_bytes, bulk_heap.freed_bytes);
        try std.testing.expectEqual(scalar_heap.has_induced_failure, bulk_heap.has_induced_failure);
        try std.testing.expectEqual(scalar_heap.allocated_bytes, scalar_heap.freed_bytes);
        try std.testing.expectEqual(bulk_heap.allocated_bytes, bulk_heap.freed_bytes);
    }
}

test "Brotli bit writer bulk Huffman matches scalar bounded progress" {
    const values = [_]u16{ 0, 1, 0x5555, 0x7fff };
    for (0..8) |offset| {
        for (1..16) |width| {
            const mask = (@as(u16, 1) << @as(u4, @intCast(width))) - 1;
            for (1..5) |capacity| {
                for (values) |bits| {
                    var scalar_storage = [_]u8{0xcc} ** 5;
                    var bulk_storage = scalar_storage;
                    scalar_storage[0] = 0xa5;
                    bulk_storage[0] = 0xa5;
                    var scalar_out: std.ArrayList(u8) = .{ .items = scalar_storage[0..1], .capacity = capacity };
                    var bulk_out: std.ArrayList(u8) = .{ .items = bulk_storage[0..1], .capacity = capacity };
                    var scalar = ReferenceWriter{ .out = &scalar_out, .bit_index = @intCast(offset), .bounded = true };
                    var bulk = BitWriter{ .out = &bulk_out, .bit_index = @intCast(offset), .bounded = true };
                    const expected: ?Error = if (scalar.writeHuffmanBits(std.testing.allocator, bits & mask, @intCast(width))) |_| null else |err| err;
                    const actual: ?Error = if (bulk.writeHuffmanBits(std.testing.allocator, bits & mask, @intCast(width))) |_| null else |err| err;
                    try std.testing.expectEqual(expected, actual);
                    try std.testing.expectEqual(scalar.bit_index, bulk.bit_index);
                    try std.testing.expectEqual(scalar_out.items.len, bulk_out.items.len);
                    try std.testing.expectEqualSlices(u8, &scalar_storage, &bulk_storage);
                }
            }
        }
    }
}
