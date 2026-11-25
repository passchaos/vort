const std = @import("std");
const fixed = @import("length_code.zig");
const oracle = @import("length_code_oracle.zig");
const block_length = @import("../../format/block_length.zig");
const generic_huffman = @import("../../../huffman.zig");
const bitstream = @import("../../../bitstream.zig");
const BitWriter = @import("../bit_writer.zig").Writer;
const distance = @import("../distance_block_split.zig");
const literal = @import("../literal_block_split.zig");
const command = @import("../command_block_split.zig");

const CountingWriter = struct {
    bits: bitstream.BitCount = 0,

    pub fn writeBits(self: *CountingWriter, _: std.mem.Allocator, _: u64, count: u6) !void {
        self.bits += count;
    }

    pub fn writeHuffmanBits(self: *CountingWriter, _: std.mem.Allocator, _: u16, count: u4) !void {
        self.bits += count;
    }
};

fn splitForLengths(comptime Split: type, lengths: []const usize) Split {
    std.debug.assert(lengths.len >= 2 and lengths.len <= 6);
    var split: Split = .{ .split = lengths[0], .savings_bits = 0 };
    var previous = lengths[0];
    for (lengths[1 .. lengths.len - 1], 1..) |length, index| {
        previous += length;
        switch (index) {
            1 => split.second_split = previous,
            2 => split.third_split = previous,
            3 => split.fourth_split = previous,
            4 => split.fifth_split = previous,
            else => unreachable,
        }
    }
    return split;
}

fn total(lengths: []const usize) usize {
    var count: usize = 0;
    for (lengths) |length| count += length;
    return count;
}

fn expectSamePlan(actual: anytype, expected: anytype) !void {
    try std.testing.expectEqual(expected.block_count, actual.block_count);
    try std.testing.expectEqual(expected.alphabet.len, actual.alphabet.len);
    try std.testing.expectEqualSlices(u16, expected.alphabet.symbols[0..expected.alphabet.len], actual.alphabet.symbols[0..actual.alphabet.len]);
    try std.testing.expectEqualSlices(u4, &expected.lengths, &actual.lengths);
    for (actual.block_lengths[0..actual.block_count], expected.block_lengths[0..expected.block_count]) |a, e| {
        try std.testing.expectEqual(e.symbol, a.symbol);
        try std.testing.expectEqual(e.extra, a.extra);
        try std.testing.expectEqual(e.extra_bits, a.extra_bits);
    }
    if (@hasField(@TypeOf(actual), "type_count"))
        try std.testing.expectEqual(expected.type_count, actual.type_count);
}

fn expectDecodedLengths(code: anytype, lengths: []const usize, output: []const u8, bit_len: bitstream.BitCount, prefix_bits: u6) !void {
    // This is the generic decoder, independent of the Brotli prefix reader and
    // the prepared encoder. The frozen RFC table supplies each extra width.
    const tree = try generic_huffman.HuffmanTable(26).init(&code.lengths);
    var reader = bitstream.BitReader.initBitLength(output, bit_len);
    try reader.skipBits(prefix_bits);
    for (lengths) |length| {
        const expected = oracle.blockLengthEncoding(length).?;
        const symbol = if (code.alphabet.len == 1) code.alphabet.symbols[0] else try tree.decodeValue(&reader);
        try std.testing.expectEqual(@as(u16, expected.symbol), symbol);
        const spec = oracle.block_length_specs[symbol];
        const extra = try reader.readBits(usize, spec.extra_bits);
        try std.testing.expectEqual(expected.extra, extra);
        try std.testing.expectEqual(length, spec.base + extra);
    }
    try std.testing.expectEqual(bit_len, reader.bitPosition());
}

fn checkComplex(comptime Code: type, comptime Split: type, comptime Old: type) !void {
    const all_lengths = [_]usize{ 4, 8, 12, 16, 24, 32 };
    for (5..7) |region_count| {
        const lengths = all_lengths[0..region_count];
        const split = splitForLengths(Split, lengths);
        const code = try Code.init(split, total(lengths));
        const old = try Old.init(split, total(lengths));
        try expectSamePlan(code, old);
        try std.testing.expectEqual(region_count, code.alphabet.len);
        const independently_built = try generic_huffman.HuffmanTable(26).Encoder.init(&old.lengths);
        for (code.alphabet.symbols[0..code.alphabet.len]) |symbol| {
            try std.testing.expectEqual(independently_built.codes[symbol], code.encoder.codes[symbol]);
            try std.testing.expectEqual(independently_built.bits[symbol], code.encoder.bits[symbol]);
        }

        var old_output: std.ArrayList(u8) = .empty;
        defer old_output.deinit(std.testing.allocator);
        var old_writer: BitWriter = .{ .out = &old_output };
        try std.testing.expectError(error.InvalidBlockPlan, old.writeLength(std.testing.allocator, &old_writer, 0));
        try std.testing.expectEqual(@as(bitstream.BitCount, 0), old_writer.bitPosition());

        for (0..8) |offset| {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(std.testing.allocator);
            var writer: BitWriter = .{ .out = &output };
            var counter: CountingWriter = .{};
            const prefix_bits: u6 = @intCast(offset);
            try writer.writeBits(std.testing.allocator, 127, prefix_bits);
            try counter.writeBits(std.testing.failing_allocator, 127, prefix_bits);
            for (0..code.block_count) |index| {
                const before = writer.bitPosition();
                try code.writeLength(std.testing.allocator, &writer, index);
                try code.writeLength(std.testing.failing_allocator, &counter, index);
                const encoding = code.block_lengths[index];
                const expected_bits = @as(bitstream.BitCount, code.lengths[encoding.symbol]) + encoding.extra_bits;
                try std.testing.expectEqual(expected_bits, writer.bitPosition() - before);
                try std.testing.expectEqual(counter.bits, writer.bitPosition());
            }
            try std.testing.expectEqual(@as(usize, @intCast((counter.bits + 7) / 8)), output.items.len);
            try std.testing.expectEqual(@as(u3, @intCast(counter.bits % 8)), writer.bit_index);
            try expectDecodedLengths(code, lengths, output.items, counter.bits, prefix_bits);
            const before = counter.bits;
            try std.testing.expectError(error.InvalidBlockPlan, code.writeLength(std.testing.failing_allocator, &counter, region_count));
            try std.testing.expectEqual(before, counter.bits);
        }
    }
}

test "fixed length codes encode five and six distinct symbols formerly rejected" {
    try checkComplex(fixed.Distance, distance.Result, oracle.Distance);
    try checkComplex(fixed.Literal, literal.Result, oracle.Literal);
    try checkComplex(fixed.Command, command.Result, oracle.Command);
}

fn checkSimple(comptime Code: type, comptime Split: type, comptime Old: type) !void {
    const cases = [_][]const usize{
        &.{ 4, 3 },
        &.{ 7, 4, 8 },
        &.{ 12, 7, 4, 8 },
        &.{ 16, 7, 12, 4, 8, 15 },
    };
    for (cases, 1..) |lengths, alphabet_size| {
        const split = splitForLengths(Split, lengths);
        const code = try Code.init(split, total(lengths));
        const old = try Old.init(split, total(lengths));
        try expectSamePlan(code, old);
        try std.testing.expectEqual(alphabet_size, code.alphabet.len);
        try std.testing.expectEqualSlices(u16, &(@as([26]u16, @splat(0))), &code.encoder.codes);
        try std.testing.expectEqualSlices(u4, &(@as([26]u4, @splat(0))), &code.encoder.bits);
        for (0..8) |offset| {
            var output: std.ArrayList(u8) = .empty;
            defer output.deinit(std.testing.allocator);
            var old_output: std.ArrayList(u8) = .empty;
            defer old_output.deinit(std.testing.allocator);
            var writer: BitWriter = .{ .out = &output };
            var old_writer: BitWriter = .{ .out = &old_output };
            var counter: CountingWriter = .{};
            const prefix_bits: u6 = @intCast(offset);
            try writer.writeBits(std.testing.allocator, 127, prefix_bits);
            try old_writer.writeBits(std.testing.allocator, 127, prefix_bits);
            try counter.writeBits(std.testing.failing_allocator, 127, prefix_bits);
            for (0..code.block_count) |index| {
                try code.writeLength(std.testing.allocator, &writer, index);
                try old.writeLength(std.testing.allocator, &old_writer, index);
                try code.writeLength(std.testing.failing_allocator, &counter, index);
                try std.testing.expectEqual(old_writer.bitPosition(), writer.bitPosition());
                try std.testing.expectEqual(counter.bits, writer.bitPosition());
                try std.testing.expectEqualSlices(u8, old_output.items, output.items);
            }
            try expectDecodedLengths(code, lengths, output.items, counter.bits, prefix_bits);
        }
    }
}

test "fixed length simple alphabets retain frozen physical bits for all alignments" {
    try checkSimple(fixed.Distance, distance.Result, oracle.Distance);
    try checkSimple(fixed.Literal, literal.Result, oracle.Literal);
    try checkSimple(fixed.Command, command.Result, oracle.Command);
}

fn checkRegions(comptime Code: type, comptime Split: type, comptime Old: type) !void {
    const all_lengths = [_]usize{ 4, 8, 12, 16, 24, 32 };
    for (2..7) |region_count| {
        const lengths = all_lengths[0..region_count];
        for (2..region_count + 1) |type_count| {
            var split = splitForLengths(Split, lengths);
            split.cycle_type_count = type_count;
            const code = try Code.init(split, total(lengths));
            const old = try Old.init(split, total(lengths));
            try expectSamePlan(code, old);
            var before: usize = 0;
            for (lengths, 0..) |length, region| {
                try std.testing.expectEqual(region % type_count, split.blockIndex(before));
                try std.testing.expectEqual(region % type_count, split.blockIndex(before + length - 1));
                before += length;
                if (region + 1 < region_count)
                    try std.testing.expectEqual((region + 1) % type_count, split.blockIndex(before));
                const expected = oracle.blockLengthEncoding(length).?;
                try std.testing.expectEqual(expected.symbol, code.block_lengths[region].symbol);
                try std.testing.expectEqual(expected.extra, code.block_lengths[region].extra);
            }
        }
    }
    for ([_]bool{ false, true }) |reuse_first| {
        var split = splitForLengths(Split, all_lengths[0..4]);
        split.alternate_two_types = !reuse_first;
        split.reuse_first_for_fourth = reuse_first;
        const code = try Code.init(split, total(all_lengths[0..4]));
        try expectSamePlan(code, try Old.init(split, total(all_lengths[0..4])));
        try std.testing.expectEqual(@as(usize, if (reuse_first) 3 else 2), split.typeCount());
        try std.testing.expectEqual(@as(usize, if (reuse_first) 0 else 1), split.blockIndex(24));
    }
}

test "fixed length codes preserve two through six ordered regions and cyclic reuse" {
    try checkRegions(fixed.Distance, distance.Result, oracle.Distance);
    try checkRegions(fixed.Literal, literal.Result, oracle.Literal);
    try checkRegions(fixed.Command, command.Result, oracle.Command);
}

fn expectInvalid(comptime Code: type, comptime Old: type, split: anytype, count: usize) !void {
    try std.testing.expectError(error.InvalidBlockPlan, Old.init(split, count));
    try std.testing.expectError(error.InvalidBlockPlan, Code.init(split, count));
}

fn checkMalformed(comptime Code: type, comptime Split: type, comptime Old: type) !void {
    const cases = [_]Split{
        .{ .split = 0, .savings_bits = 0 },
        .{ .split = 32, .savings_bits = 0 },
        .{ .split = 33, .savings_bits = 0 },
        .{ .split = 8, .second_split = 8, .savings_bits = 0 },
        .{ .split = 8, .second_split = 7, .savings_bits = 0 },
        .{ .split = 8, .second_split = 32, .savings_bits = 0 },
        .{ .split = 8, .third_split = 24, .savings_bits = 0 },
        .{ .split = 8, .fourth_split = 24, .savings_bits = 0 },
        .{ .split = 8, .fifth_split = 24, .savings_bits = 0 },
        .{ .split = 8, .second_split = 16, .fourth_split = 24, .savings_bits = 0 },
        .{ .split = 8, .second_split = 16, .third_split = 24, .fifth_split = 28, .savings_bits = 0 },
        .{ .split = 8, .second_split = 16, .third_split = 24, .fourth_split = 24, .savings_bits = 0 },
        .{ .split = 8, .cycle_type_count = 0, .savings_bits = 0 },
        .{ .split = 8, .cycle_type_count = 1, .savings_bits = 0 },
        .{ .split = 8, .cycle_type_count = 3, .savings_bits = 0 },
    };
    for (cases) |split| try expectInvalid(Code, Old, split, 32);
    try expectInvalid(Code, Old, @as(Split, .{ .split = 1, .savings_bits = 0 }), 0);
    try expectInvalid(Code, Old, @as(Split, .{ .split = 1, .savings_bits = 0 }), 1);
    try expectInvalid(Code, Old, @as(Split, .{ .split = 1, .savings_bits = 0 }), block_length.max_encoder_length + 2);
    try expectInvalid(Code, Old, @as(Split, .{ .split = block_length.max_encoder_length + 1, .savings_bits = 0 }), block_length.max_encoder_length + 2);
    // The cap applies to each region, as in the original; two maximal regions
    // are allowed even though their combined stream length exceeds the cap.
    const maximum = try Code.init(.{ .split = block_length.max_encoder_length, .savings_bits = 0 }, 2 * block_length.max_encoder_length);
    const old = try Old.init(.{ .split = block_length.max_encoder_length, .savings_bits = 0 }, 2 * block_length.max_encoder_length);
    try expectSamePlan(maximum, old);
    try std.testing.expectEqual(@as(u5, 25), maximum.block_lengths[0].symbol);
    try std.testing.expectEqual(@as(u5, 24), maximum.block_lengths[0].extra_bits);
}

test "fixed length malformed shapes and per-region maximum retain exact errors" {
    try checkMalformed(fixed.Distance, distance.Result, oracle.Distance);
    try checkMalformed(fixed.Literal, literal.Result, oracle.Literal);
    try checkMalformed(fixed.Command, command.Result, oracle.Command);
}

fn checkPermissiveReuse(comptime Code: type, comptime Split: type, comptime Old: type) !void {
    const all_lengths = [_]usize{ 4, 8, 12, 16, 24, 32 };
    for (3..7) |regions| {
        for (0..4) |mode| {
            var split = splitForLengths(Split, all_lengths[0..regions]);
            switch (mode) {
                0 => split.reuse_first_for_fourth = true,
                1 => split.alternate_two_types = true,
                2 => {
                    split.alternate_two_types = true;
                    split.reuse_first_for_fourth = true;
                },
                3 => {
                    split.cycle_type_count = 2;
                    split.alternate_two_types = true;
                    split.reuse_first_for_fourth = true;
                },
                else => unreachable,
            }
            const count = total(all_lengths[0..regions]);
            const code = try Code.init(split, count);
            try expectSamePlan(code, try Old.init(split, count));
        }
    }
}

test "fixed distance and command do not acquire stricter literal reuse validation" {
    try checkPermissiveReuse(fixed.Distance, distance.Result, oracle.Distance);
    try checkPermissiveReuse(fixed.Command, command.Result, oracle.Command);
    const cases = [_]literal.Result{
        .{ .split = 4, .second_split = 12, .reuse_first_for_fourth = true, .savings_bits = 0 },
        .{ .split = 4, .second_split = 12, .third_split = 24, .alternate_two_types = true, .reuse_first_for_fourth = true, .savings_bits = 0 },
        .{ .split = 4, .second_split = 12, .third_split = 24, .cycle_type_count = 2, .alternate_two_types = true, .savings_bits = 0 },
        .{ .split = 4, .second_split = 12, .third_split = 24, .cycle_type_count = 2, .reuse_first_for_fourth = true, .savings_bits = 0 },
        .{ .split = 4, .second_split = 12, .third_split = 24, .fourth_split = 40, .alternate_two_types = true, .savings_bits = 0 },
        .{ .split = 4, .second_split = 12, .third_split = 24, .fourth_split = 40, .reuse_first_for_fourth = true, .savings_bits = 0 },
    };
    for (cases) |split| try expectInvalid(fixed.Literal, oracle.Literal, split, 64);
}
