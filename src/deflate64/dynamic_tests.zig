//! Independent bit-by-bit dynamic header/payload inspection. Code selection,
//! RLE expansion and cost accounting do not use production code classifiers.
const std = @import("std");
const decoder = @import("decoder.zig");
const matching = @import("stream_match.zig");
const order = [_]u8{ 16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15 };

const Reader = struct {
    bytes: []const u8,
    position: usize = 0,

    fn bits(self: *Reader, width: u6) !u32 {
        if (width > 16 or @as(u128, self.position) + width > @as(u128, self.bytes.len) * 8) return error.TruncatedFrame;
        var value: u32 = 0;
        for (0..width) |bit| {
            const position = self.position + bit;
            value |= @as(u32, (self.bytes[position / 8] >> @as(u3, @intCast(position % 8))) & 1) << @as(u5, @intCast(bit));
        }
        self.position += width;
        return value;
    }
    fn symbol(self: *Reader, lengths: []const u4) !u16 {
        var counts: [16]u16 = @splat(0);
        for (lengths) |width| if (width != 0) {
            counts[width] += 1;
        };
        var canonical: u32 = 0;
        var value: u32 = 0;
        for (1..16) |width| {
            canonical = (canonical + counts[width - 1]) << 1;
            value = (value << 1) | try self.bits(1);
            if (value < canonical or value >= canonical + counts[width]) continue;
            var rank = value - canonical;
            for (lengths, 0..) |length, index| {
                if (length != width) continue;
                if (rank == 0) return @intCast(index);
                rank -= 1;
            }
            return error.InvalidHuffmanCode;
        }
        return error.InvalidHuffmanCode;
    }
};

const Inspection = struct {
    hlit: usize,
    hdist: usize,
    hclen: usize,
    literal_lengths: [286]u4,
    distance_lengths: [32]u4,
    code_length_lengths: [19]u4,
    header_bits: usize,
    payload_bits: usize,
    fixed_bits: usize,
    max_length: usize = 0,
    max_distance: usize = 0,
    match_count: usize = 0,
};

fn inspect(reader: *Reader, output_len: usize, history_len: usize, final: bool) !Inspection {
    const start = reader.position;
    try std.testing.expectEqual(@as(u32, @intFromBool(final)), try reader.bits(1));
    try std.testing.expectEqual(@as(u32, 2), try reader.bits(2));
    const hlit: usize = 257 + try reader.bits(5);
    const hdist: usize = 1 + try reader.bits(5);
    const hclen: usize = 4 + try reader.bits(4);
    try std.testing.expect(hlit <= 286 and hdist <= 32 and hclen <= 19);
    var code_lengths: [19]u4 = @splat(0);
    for (order[0..hclen]) |symbol| code_lengths[symbol] = @intCast(try reader.bits(3));
    var expanded: [318]u4 = @splat(0);
    var written: usize = 0;
    while (written < hlit + hdist) {
        const symbol = try reader.symbol(&code_lengths);
        var value: u4 = 0;
        var count: usize = 1;
        if (symbol < 16) {
            value = @intCast(symbol);
        } else if (symbol == 16) {
            if (written == 0) return error.InvalidDynamicBlockHeader;
            value = expanded[written - 1];
            count = 3 + try reader.bits(2);
        } else if (symbol == 17) {
            count = 3 + try reader.bits(3);
        } else if (symbol == 18) {
            count = 11 + try reader.bits(7);
        } else return error.InvalidDynamicBlockHeader;
        if (count > hlit + hdist - written) return error.InvalidDynamicBlockHeader;
        @memset(expanded[written..][0..count], value);
        written += count;
    }
    var result: Inspection = .{
        .hlit = hlit,
        .hdist = hdist,
        .hclen = hclen,
        .literal_lengths = @splat(0),
        .distance_lengths = @splat(0),
        .code_length_lengths = code_lengths,
        .header_bits = reader.position - start,
        .payload_bits = 0,
        .fixed_bits = 3,
    };
    @memcpy(result.literal_lengths[0..hlit], expanded[0..hlit]);
    @memcpy(result.distance_lengths[0..hdist], expanded[hlit..][0..hdist]);
    try std.testing.expect(result.literal_lengths[256] != 0);
    const payload_start = reader.position;
    var produced: usize = 0;
    while (true) {
        const symbol = try reader.symbol(&result.literal_lengths);
        const fixed_width: usize = if (symbol <= 143) 8 else if (symbol <= 255) 9 else if (symbol <= 279) 7 else 8;
        result.fixed_bits += fixed_width;
        if (symbol < 256) {
            produced += 1;
        } else if (symbol == 256) {
            break;
        } else {
            if (symbol > 285) return error.InvalidHuffmanCode;
            const length_bits: u6 = if (symbol <= 264) 0 else if (symbol == 285) 16 else @intCast((symbol - 265) / 4 + 1);
            const length_base: usize = if (symbol <= 264)
                symbol - 254
            else if (symbol == 285)
                3
            else
                (@as(usize, 1) << @intCast(length_bits + 2)) + 3 +
                    @as(usize, (symbol - 265) % 4) * (@as(usize, 1) << @intCast(length_bits));
            const length = length_base + try reader.bits(length_bits);
            const distance_symbol = try reader.symbol(&result.distance_lengths);
            if (distance_symbol >= 32) return error.InvalidHuffmanCode;
            const distance_bits: u6 = if (distance_symbol < 4) 0 else @intCast(distance_symbol / 2 - 1);
            const distance_base: usize = if (distance_symbol < 4)
                distance_symbol + 1
            else
                ((2 + @as(usize, distance_symbol & 1)) << @intCast(distance_bits)) + 1;
            const distance = distance_base + try reader.bits(distance_bits);
            try std.testing.expect(distance <= produced + history_len and distance <= 65536);
            result.fixed_bits += @as(usize, length_bits) + 5 + distance_bits;
            result.match_count += 1;
            result.max_length = @max(result.max_length, length);
            result.max_distance = @max(result.max_distance, distance);
            produced += length;
        }
        try std.testing.expect(produced <= output_len);
    }
    result.payload_bits = reader.position - payload_start;
    try std.testing.expectEqual(output_len, produced);
    return result;
}

fn completeSpace(lengths: []const u4, max_bits: u4) !void {
    var remaining: i32 = @as(i32, 1) << @as(u5, max_bits);
    var active: usize = 0;
    for (lengths) |length| {
        if (length == 0) continue;
        try std.testing.expect(length <= max_bits);
        active += 1;
        remaining -= @as(i32, 1) << @as(u5, max_bits - length);
    }
    try std.testing.expect(active >= 2);
    try std.testing.expectEqual(@as(i32, 0), remaining);
}

fn exactBlock(comptime Blocks: type, input: []const u8, max_chain: usize) !void {
    var matcher: matching.Matcher = .{};
    defer matcher.deinit(std.testing.allocator);
    if (input.len != 0) try matcher.ensureForSize(std.testing.allocator, input.len);
    const plan = try Blocks.dynamicPlan(&matcher, "", input, max_chain, 65538);
    const fixed = Blocks.fixedPlan(&matcher, "", input, max_chain, 65538);
    try std.testing.expectEqual(fixed.bits, plan.fixed_bits);
    try std.testing.expectEqualDeep(fixed.stats, plan.stats);
    try std.testing.expectEqual(plan.bits, plan.header_bits + plan.payload_bits);
    try completeSpace(&plan.literal_lengths, 15);
    try completeSpace(&plan.distance_lengths, 15);
    try completeSpace(&plan.code_length_lengths, 7);
    if (input.len == 0) {
        try std.testing.expectEqual(@as(usize, 1), plan.payload_bits); // Real EOB only, no synthetic distance cost.
        try std.testing.expectEqual(@as(usize, 2), plan.hdist);
    }
    for (0..8) |q| {
        const prefix_len = (q + 6) % 8;
        const prefix_storage: [7]u8 = @splat(144);
        const prefix = prefix_storage[0..prefix_len];
        if (prefix.len != 0) try matcher.ensureForSize(std.testing.allocator, @max(input.len, prefix.len));
        const prefix_bits = 10 + prefix_len * 9;
        for ([_]bool{ false, true }) |final| {
            const total_bits = prefix_bits + plan.bits + if (final) @as(usize, 0) else 10;
            const wire = try std.testing.allocator.alloc(u8, (total_bits + 7) / 8);
            defer std.testing.allocator.free(wire);
            var writer: Blocks.Writer = .{ .state = .{}, .output = wire };
            Blocks.writeFixed(&writer, &matcher, "", prefix, 0, 65538, false);
            try std.testing.expectEqual(@as(u3, @intCast(q)), writer.state.bit_index);
            const start = writer.len * 8 + writer.state.bit_index;
            Blocks.writeDynamic(&writer, &matcher, "", input, max_chain, 65538, final, &plan);
            try std.testing.expectEqual(start + plan.bits, writer.len * 8 + writer.state.bit_index);
            if (!final) Blocks.writeFixed(&writer, &matcher, "", "", 0, 65538, true);
            writer.alignToByte();
            try std.testing.expectEqual(wire.len, writer.len);
            var reader: Reader = .{ .bytes = wire, .position = start };
            const observed = try inspect(&reader, input.len, prefix.len, final);
            try std.testing.expectEqual(plan.header_bits, observed.header_bits);
            try std.testing.expectEqual(plan.payload_bits, observed.payload_bits);
            try std.testing.expectEqual(plan.fixed_bits, observed.fixed_bits);
            try std.testing.expectEqual(plan.stats.match_count, observed.match_count);
            try std.testing.expectEqual(plan.stats.max_match_length, observed.max_length);
            try std.testing.expectEqual(plan.stats.max_match_distance, observed.max_distance);
            try std.testing.expectEqualDeep(plan.literal_lengths, observed.literal_lengths);
            try std.testing.expectEqualDeep(plan.distance_lengths, observed.distance_lengths);
            try std.testing.expectEqualDeep(plan.code_length_lengths, observed.code_length_lengths);
            const plain = try decoder.decodeAlloc(std.testing.allocator, wire);
            defer std.testing.allocator.free(plain);
            try std.testing.expectEqualSlices(u8, prefix, plain[0..prefix.len]);
            try std.testing.expectEqualSlices(u8, input, plain[prefix.len..]);
        }
    }
}

fn maximumDistance(comptime Blocks: type) !void {
    const input = try std.testing.allocator.alloc(u8, 2 * 65536);
    defer std.testing.allocator.free(input);
    var random: u32 = 0x65362026;
    for (input[0..65536]) |*byte| {
        random = random *% 1664525 +% 1013904223;
        byte.* = @truncate(random >> 24);
    }
    @memcpy(input[65536..], input[0..65536]);
    var matcher: matching.Matcher = .{};
    defer matcher.deinit(std.testing.allocator);
    try matcher.ensureForSize(std.testing.allocator, input.len);
    const plan = try Blocks.dynamicPlan(&matcher, input[0..65536], input[65536..], 128, 65538);
    try std.testing.expectEqual(@as(usize, 65536), plan.stats.max_match_distance);
    try std.testing.expectEqual(@as(usize, 32), plan.hdist);
    try std.testing.expectEqual(@as(usize, 286), plan.hlit);
    const prefix_bits = Blocks.storedBits(.{}, 65536);
    const wire = try std.testing.allocator.alloc(u8, (prefix_bits + plan.bits + 7) / 8);
    defer std.testing.allocator.free(wire);
    var writer: Blocks.Writer = .{ .state = .{}, .output = wire };
    Blocks.writeStored(&writer, input[0..65536], false);
    const start = writer.len * 8;
    Blocks.writeDynamic(&writer, &matcher, input[0..65536], input[65536..], 128, 65538, true, &plan);
    writer.alignToByte();
    try std.testing.expectEqual(wire.len, writer.len);
    var reader: Reader = .{ .bytes = wire, .position = start };
    const observed = try inspect(&reader, 65536, 65536, true);
    try std.testing.expectEqual(@as(usize, 65536), observed.max_distance);
    try std.testing.expectEqual(@as(usize, 65536), observed.max_length);
    try std.testing.expectEqual(plan.bits, observed.header_bits + observed.payload_bits);
    const plain = try decoder.decodeAlloc(std.testing.allocator, wire);
    defer std.testing.allocator.free(plain);
    try std.testing.expectEqualSlices(u8, input, plain);
}

fn codeRanges() !void {
    const codes = @import("codes.zig");
    const length_bases = [_]usize{ 3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227 };
    const length_widths = [_]u5{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5 };
    for (3..65539) |length| {
        const actual = codes.lengthCode(length);
        if (length > 258) {
            try std.testing.expectEqual(@as(u16, 285), actual.symbol);
            try std.testing.expectEqual(@as(u5, 16), actual.bits);
            try std.testing.expectEqual(@as(u16, @intCast(length - 3)), actual.value);
        } else {
            var found = false;
            for (length_bases, length_widths, 0..) |base, width, index| {
                if (length < base or length - base >= (@as(usize, 1) << @intCast(width))) continue;
                try std.testing.expectEqual(@as(u16, @intCast(257 + index)), actual.symbol);
                try std.testing.expectEqual(width, actual.bits);
                try std.testing.expectEqual(@as(u16, @intCast(length - base)), actual.value);
                found = true;
                break;
            }
            try std.testing.expect(found);
        }
    }
    const distance_bases = [_]usize{ 1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577, 32769, 49153 };
    const distance_widths = [_]u5{ 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13, 14, 14 };
    for (1..65537) |distance| {
        const actual = codes.distanceCode(distance);
        var found = false;
        for (distance_bases, distance_widths, 0..) |base, width, index| {
            if (distance < base or distance - base >= (@as(usize, 1) << @intCast(width))) continue;
            try std.testing.expectEqual(@as(u16, @intCast(index)), actual.symbol);
            try std.testing.expectEqual(width, actual.bits);
            try std.testing.expectEqual(@as(u16, @intCast(distance - base)), actual.value);
            found = true;
            break;
        }
        try std.testing.expect(found);
    }
}

pub fn contracts(comptime Blocks: type) !void {
    try codeRanges();
    inline for (.{ "", "x", "abc", "R" ** 259, "Deflate64 dynamic planning and exact header tests\n" ** 8 }) |input|
        try exactBlock(Blocks, input, 128);
    var literals: [257]u8 = undefined;
    for (&literals, 0..) |*byte, index| byte.* = @truncate(index);
    try exactBlock(Blocks, &literals, 0);
    const longest: [65539]u8 = @splat('R');
    try exactBlock(Blocks, &longest, 128);
    try maximumDistance(Blocks);
    var matcher: matching.Matcher = .{};
    const huge_block = try std.testing.allocator.alloc(u8, 131073);
    defer std.testing.allocator.free(huge_block);
    try std.testing.expectError(error.InvalidBlockPlan, Blocks.dynamicPlan(&matcher, "", huge_block, 128, 128));
    try std.testing.expectError(error.InvalidBlockPlan, Blocks.dynamicPlan(&matcher, huge_block[0..65537], "", 128, 128));
}
