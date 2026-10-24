//! Independent RFC 7932 wire mathematics and frozen pre-HQ fixtures.
const std = @import("std");

pub const insert_bases = [_]u32{ 0, 1, 2, 3, 4, 5, 6, 8, 10, 14, 18, 26, 34, 50, 66, 98, 130, 194, 322, 578, 1090, 2114, 6210, 22594 };
pub const insert_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 12, 14, 24 };
pub const copy_bases = [_]u32{ 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 14, 18, 22, 30, 38, 54, 70, 102, 134, 198, 326, 582, 1094, 2118 };
pub const copy_bits = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 9, 10, 24 };

pub const Command = struct { insert_code: u8, copy_code: u8, implicit_last_distance: bool };
const explicit_groups = [3][3]u16{ .{ 128, 192, 384 }, .{ 256, 320, 512 }, .{ 448, 576, 640 } };

pub fn command(symbol: u16) Command {
    std.debug.assert(symbol < 704);
    if (symbol < 128) return .{ .insert_code = @intCast((symbol & 63) >> 3), .copy_code = @intCast((symbol & 7) + if (symbol >= 64) @as(u16, 8) else 0), .implicit_last_distance = true };
    for (explicit_groups, 0..) |row, insert_group| {
        for (row, 0..) |base, copy_group| {
            if (symbol >= base and symbol < base + 64) return .{ .insert_code = @intCast(insert_group * 8 + (symbol - base) / 8), .copy_code = @intCast(copy_group * 8 + (symbol - base) % 8), .implicit_last_distance = false };
        }
    }
    unreachable;
}

/// Semantic cache order is newest to oldest, independent of decoder rings.
pub fn shortDistance(cache: [4]usize, code: u4) ?usize {
    if (code < 4) return cache[code];
    const slot: usize = if (code < 10) 0 else 1;
    const local: usize = if (code < 10) code - 4 else code - 10;
    const magnitude = local / 2 + 1;
    if (local % 2 == 0) return if (cache[slot] > magnitude) cache[slot] - magnitude else null;
    return std.math.add(usize, cache[slot], magnitude) catch null;
}

pub fn afterDistance(cache: [4]usize, code: usize, distance: usize, static_dictionary: bool) [4]usize {
    if (code == 0 or static_dictionary) return cache;
    return .{ distance, cache[0], cache[1], cache[2] };
}

pub const Distance = struct { symbol: u16, extra_bits: u8, extra: usize };

pub fn alphabetSize(postfix: u2, direct: u16) usize {
    return 16 + @as(usize, direct) + (@as(usize, 48) << @as(u6, postfix));
}

pub fn distanceEncoding(distance: usize, postfix: u2, direct: u16) Distance {
    std.debug.assert(distance > 0);
    if (distance <= direct) return .{ .symbol = @intCast(15 + distance), .extra_bits = 0, .extra = 0 };
    const low_mask = (@as(usize, 1) << postfix) - 1;
    const value = distance - direct - 1;
    const low = value & low_mask;
    const high = (value >> postfix) + 4;
    const bits = std.math.log2_int(usize, high) - 1;
    const prefix = (high >> @intCast(bits)) & 1;
    const extra = high - ((2 + prefix) << @intCast(bits));
    const symbol = 16 + @as(usize, direct) + ((2 * (bits - 1) + prefix) << postfix) + low;
    return .{ .symbol = @intCast(symbol), .extra_bits = @intCast(bits), .extra = extra };
}

pub fn distanceDecoding(encoded: Distance, postfix: u2, direct: u16) usize {
    if (encoded.symbol < 16 + direct) return encoded.symbol - 15;
    const value = encoded.symbol - 16 - direct;
    const low = value & ((@as(u16, 1) << postfix) - 1);
    const group = value >> postfix;
    const bits = (group >> 1) + 1;
    const prefix = group & 1;
    return (((@as(usize, 2 + prefix) << @intCast(bits)) - 4 + encoded.extra) << postfix) + low + direct + 1;
}

pub const legacy_plain = "Brotli scheduled baseline: abcdefghabcdefghXbcdefghYabcdefgh; dictionary and literal modes.\n" ** 3;

pub fn boundaryInput(allocator: std.mem.Allocator) ![]u8 {
    const output = try allocator.alloc(u8, 4098);
    var symbols: [3]u8 = @splat(0);
    var written: usize = 0;
    deBruijn2(output[0..4094], &written, &symbols, 1, 1);
    std.debug.assert(written == 4094);
    @memcpy(output[0..4], "txyz");
    @memcpy(output[4094..], "txyz");
    return output;
}

fn deBruijn2(output: []u8, written: *usize, symbols: *[3]u8, position: usize, period: usize) void {
    if (written.* == output.len) return;
    if (position > 2) {
        if (2 % period == 0) for (symbols[1..][0..period]) |byte| {
            if (written.* == output.len) return;
            output[written.*] = byte;
            written.* += 1;
        };
        return;
    }
    symbols[position] = symbols[position - period];
    deBruijn2(output, written, symbols, position + 1, period);
    var next: usize = @as(usize, symbols[position - period]) + 1;
    while (next < 128 and written.* != output.len) : (next += 1) {
        symbols[position] = @intCast(next);
        deBruijn2(output, written, symbols, position + 1, position);
    }
}

pub fn boundaryCommandPrice(symbol: usize) u64 {
    return if (symbol == 488 or symbol == 144) 1 else 64;
}

pub fn commandCost(insert_len: usize, copy_len: usize, has_copy: bool, distance: usize) u64 {
    var best: u64 = std.math.maxInt(u64);
    for (0..704) |symbol| {
        const entry = command(@intCast(symbol));
        const ibits = insert_bits[entry.insert_code];
        const cbits = copy_bits[entry.copy_code];
        if (insert_len < insert_bases[entry.insert_code] or insert_len - insert_bases[entry.insert_code] >= (@as(usize, 1) << @intCast(ibits))) continue;
        if (copy_len < copy_bases[entry.copy_code] or copy_len - copy_bases[entry.copy_code] >= (@as(usize, 1) << @intCast(cbits))) continue;
        if (has_copy and entry.implicit_last_distance) continue;
        const extra: u64 = if (has_copy) distanceEncoding(distance, 0, 0).extra_bits else 0;
        best = @min(best, boundaryCommandPrice(symbol) + ibits + cbits + extra);
    }
    return best;
}

/// Finite independent enumeration over every legal suffix match/length. Other
/// preamble commands have a 64-bit price and cannot save their two-byte copies.
pub fn boundaryMinimumCost(input: []const u8) u64 {
    var best = @as(u64, @intCast(input.len)) * 8 + commandCost(input.len, 2, false, 0);
    for (4094..input.len - 1) |position| {
        for (0..position) |candidate| {
            var length: usize = 0;
            while (length < input.len - position and input[candidate + length] == input[position + length]) : (length += 1) {}
            if (length < 2) continue;
            const distance = position - candidate;
            const encoded = distanceEncoding(distance, 0, 0);
            if (encoded.symbol != 36) continue;
            for (2..length + 1) |copy_len| {
                const tail = input.len - position - copy_len;
                const literals = position + tail;
                const cost = @as(u64, @intCast(literals)) * 8 + commandCost(position, copy_len, true, distance) + if (tail != 0) commandCost(tail, 2, false, 0) else @as(u64, 0);
                best = @min(best, cost);
            }
        }
    }
    return best;
}

pub fn replayLzPlan(allocator: std.mem.Allocator, input: []const u8, plan: anytype) !void {
    const output = try allocator.alloc(u8, input.len);
    defer allocator.free(output);
    var position: usize = 0;
    var cache: [4]usize = .{ 4, 11, 15, 16 };
    for (plan.commands) |command_item| {
        const exact = command_item.hq_encoding orelse return error.TestUnexpectedResult;
        const entry = command(exact.command_symbol);
        const insert_base: usize = insert_bases[entry.insert_code];
        const copy_base: usize = copy_bases[entry.copy_code];
        try std.testing.expect(command_item.insert_len >= insert_base and command_item.insert_len - insert_base < (@as(usize, 1) << @intCast(insert_bits[entry.insert_code])));
        try std.testing.expect(command_item.copy_len >= copy_base and command_item.copy_len - copy_base < (@as(usize, 1) << @intCast(copy_bits[entry.copy_code])));
        try std.testing.expectEqual(position, command_item.insert_start);
        try std.testing.expect(command_item.insert_len <= input.len - position);
        @memcpy(output[position..][0..command_item.insert_len], input[position..][0..command_item.insert_len]);
        position += command_item.insert_len;
        if (command_item.has_copy) {
            try std.testing.expect(command_item.source == .lz77);
            const distance = if (exact.distance_code < 16) shortDistance(cache, @intCast(exact.distance_code)) orelse return error.TestUnexpectedResult else exact.distance_code - 15;
            try std.testing.expectEqual(distance, command_item.distance);
            try std.testing.expect(distance != 0 and distance <= position);
            try std.testing.expect(command_item.copy_len <= output.len - position);
            if (entry.implicit_last_distance) {
                try std.testing.expectEqual(@as(usize, 0), exact.distance_code);
                try std.testing.expect(exact.distance_encoding == null);
            } else {
                const encoded = exact.distance_encoding orelse return error.TestUnexpectedResult;
                if (encoded.symbol < 16) {
                    try std.testing.expectEqual(exact.distance_code, encoded.symbol);
                } else {
                    try std.testing.expectEqual(distance, distanceDecoding(.{ .symbol = encoded.symbol, .extra = encoded.extra, .extra_bits = encoded.extra_bits }, exact.distance_parameters.npostfix, exact.distance_parameters.ndirect()));
                }
            }
            for (0..command_item.copy_len) |_| {
                output[position] = output[position - distance];
                position += 1;
            }
            cache = afterDistance(cache, exact.distance_code, distance, false);
        }
    }
    try std.testing.expectEqual(input.len, position);
    try std.testing.expectEqualSlices(u8, input, output);
    for (cache, 0..) |distance, index| try std.testing.expectEqual(distance, plan.final_recent_distances[3 - index]);
}

pub fn decodeHex(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    const output = try allocator.alloc(u8, text.len / 2);
    errdefer allocator.free(output);
    _ = try std.fmt.hexToBytes(output, text);
    return output;
}

pub fn sentinel(bytes: []const u8) !void {
    for (bytes) |byte| try std.testing.expectEqual(@as(u8, 0xa5), byte);
}

pub fn drive(allocator: std.mem.Allocator, encoder: anytype, input: []const u8, input_chunk: usize, output_chunk: usize) ![]u8 {
    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);
    const initial = encoder.snapshot();
    var offset = initial.input_read;
    var finished = initial.finishing;
    var incoming: [257]u8 = undefined;
    var outgoing: [31]u8 = undefined;
    var calls: usize = 0;
    while (true) : (calls += 1) {
        try std.testing.expect(calls < (input.len + 1) * 16 + 4096);
        if (offset == input.len and !finished) {
            try encoder.finish();
            finished = true;
        }
        const take = @min(input_chunk, input.len - offset);
        @memcpy(incoming[0..take], input[offset..][0..take]);
        @memset(&outgoing, 0xa5);
        const quota: usize = if (calls % 5 == 0) 0 else output_chunk;
        const before = encoder.snapshot();
        const step = try encoder.step(incoming[0..take], outgoing[0..quota]);
        const after = encoder.snapshot();
        try std.testing.expect(step.progress.input_read <= take and step.progress.output_written <= quota);
        try std.testing.expectEqual(step.progress.input_read, after.input_read - before.input_read);
        try std.testing.expectEqual(step.progress.output_written, after.output_written - before.output_written);
        try sentinel(outgoing[step.progress.output_written..]);
        offset += step.progress.input_read;
        try output.appendSlice(allocator, outgoing[0..step.progress.output_written]);
        @memset(&incoming, 0x3c);
        if (step.status == .done) {
            try std.testing.expectEqual(input.len, offset);
            try std.testing.expectEqual(output.items.len, after.output_written - initial.output_written);
            return output.toOwnedSlice(allocator);
        }
    }
}

pub const Bits = struct {
    bytes: []const u8,
    position: usize = 0,

    pub fn read(self: *Bits, width: u8) !usize {
        if (width > @bitSizeOf(usize) or self.position + width > self.bytes.len * 8) return error.TestUnexpectedResult;
        var value: usize = 0;
        for (0..width) |index| {
            const bit = self.position + index;
            value |= @as(usize, (self.bytes[bit / 8] >> @as(u3, @intCast(bit % 8))) & 1) << @intCast(index);
        }
        self.position += width;
        return value;
    }

    fn varUint8(self: *Bits) !usize {
        if (try self.read(1) == 0) return 0;
        const width = try self.read(3);
        if (width == 0) return 1;
        return (@as(usize, 1) << @intCast(width)) + try self.read(@intCast(width));
    }
};

const SimpleTree = struct {
    symbols: [4]usize = @splat(0),
    lengths: [4]u8 = @splat(0),
    count: usize,

    fn read(reader: *Bits, alphabet: usize) !SimpleTree {
        if (try reader.read(2) != 1) return error.UnsupportedTestFixture;
        var result: SimpleTree = .{ .count = 1 + try reader.read(2) };
        const symbol_bits = std.math.log2_int_ceil(usize, alphabet);
        for (result.symbols[0..result.count]) |*symbol| {
            symbol.* = try reader.read(@intCast(symbol_bits));
            if (symbol.* >= alphabet) return error.TestUnexpectedResult;
        }
        result.lengths = switch (result.count) {
            1 => .{ 0, 0, 0, 0 },
            2 => .{ 1, 1, 0, 0 },
            3 => .{ 1, 2, 2, 0 },
            4 => if (try reader.read(1) == 0) .{ 2, 2, 2, 2 } else .{ 1, 2, 3, 3 },
            else => unreachable,
        };
        return result;
    }

    fn decode(self: SimpleTree, reader: *Bits) !usize {
        if (self.count == 1) return self.symbols[0];
        var counts: [4]usize = @splat(0);
        for (self.lengths[0..self.count]) |length| counts[length] += 1;
        var code: usize = 0;
        var first: usize = 0;
        for (1..4) |length| {
            code = (code << 1) | try reader.read(1);
            if (code >= first and code - first < counts[length]) {
                var candidates: [4]usize = undefined;
                var used: usize = 0;
                for (0..self.count) |index| if (self.lengths[index] == length) {
                    candidates[used] = self.symbols[index];
                    used += 1;
                };
                std.mem.sort(usize, candidates[0..used], {}, std.sort.asc(usize));
                return candidates[code - first];
            }
            first = (first + counts[length]) << 1;
        }
        return error.TestUnexpectedResult;
    }
};

pub const SingleCommandWire = struct {
    window_bits: usize,
    meta_len: usize,
    command_symbol: usize,
    insert_len: usize,
    raw_copy_len: usize,
    distance_symbol: ?usize,
    distance: usize,
    npostfix: u2,
    ndirect: u16,
};

/// Independent limited RFC reader for deliberately simple one-command fixtures.
/// It reads real tree symbols and extra bits, never producer-selected metadata.
pub fn singleCommandWire(bytes: []const u8, semantic_cache: [4]usize) !SingleCommandWire {
    var reader: Bits = .{ .bytes = bytes };
    var window: usize = 16;
    if (try reader.read(1) != 0) {
        const middle = try reader.read(3);
        if (middle != 0) window = 17 + middle else {
            const lower = try reader.read(3);
            window = if (lower == 0) 17 else 8 + lower;
        }
    }
    const last = try reader.read(1) != 0;
    if (last and try reader.read(1) != 0) return error.UnsupportedTestFixture;
    const nibbles = 4 + try reader.read(2);
    if (nibbles == 7) return error.UnsupportedTestFixture;
    const meta_len = 1 + try reader.read(@intCast(nibbles * 4));
    if (!last and try reader.read(1) != 0) return error.UnsupportedTestFixture;
    for (0..3) |_| if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    const postfix: u2 = @intCast(try reader.read(2));
    const direct: u16 = @intCast((try reader.read(4)) << postfix);
    _ = try reader.read(2);
    if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    if (try reader.varUint8() != 0) return error.UnsupportedTestFixture;
    const literals = try SimpleTree.read(&reader, 256);
    const commands = try SimpleTree.read(&reader, 704);
    const distances = try SimpleTree.read(&reader, alphabetSize(postfix, direct));
    const symbol = try commands.decode(&reader);
    const entry = command(@intCast(symbol));
    const insert_len = insert_bases[entry.insert_code] + try reader.read(insert_bits[entry.insert_code]);
    const raw_copy_len = copy_bases[entry.copy_code] + try reader.read(copy_bits[entry.copy_code]);
    for (0..insert_len) |_| _ = try literals.decode(&reader);
    var distance_symbol: ?usize = null;
    var distance = semantic_cache[0];
    if (!entry.implicit_last_distance) {
        const dcode = try distances.decode(&reader);
        distance_symbol = dcode;
        if (dcode < 16) distance = shortDistance(semantic_cache, @intCast(dcode)) orelse return error.TestUnexpectedResult else {
            const bits: u8 = if (dcode < 16 + direct) 0 else @intCast((((dcode - 16 - direct) >> postfix) >> 1) + 1);
            const extra = try reader.read(bits);
            distance = distanceDecoding(.{ .symbol = @intCast(dcode), .extra_bits = bits, .extra = extra }, postfix, direct);
        }
    }
    return .{ .window_bits = window, .meta_len = meta_len, .command_symbol = symbol, .insert_len = insert_len, .raw_copy_len = raw_copy_len, .distance_symbol = distance_symbol, .distance = distance, .npostfix = postfix, .ndirect = direct };
}

// Complete old null-HQ wires, independently captured from a2cfc30b.
pub const LegacyWire = struct { api: enum { one_shot, reusable, chunks, incremental }, quality: u4, mode: []const u8, hex: []const u8 };
pub const legacy_wires = [_]LegacyWire{
    .{ .api = .one_shot, .quality = 0, .mode = "generic", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .reusable, .quality = 0, .mode = "generic", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .chunks, .quality = 0, .mode = "generic", .hex = "00011042726f746c69207363686564756c656420580208626173656c696e653a206162636465666768616263646566676858626364656667685961626364656667683b2064696374696f6e61727920616e64206c69746572616c206d6f6465732e0a42b005000000d44d8f51150a21c06114c89e97942dd9860080ba79f55fa9360643eb310cc3300c1b43350c1f1fc330ccb13154c3300cc3300c00b68d3115b19b8c26465f95303954be5201c2a9954d0f406251f34038403700e829091b38419257f686e3076c02954b0716bc5d74eedb359a3f4830" },
    .{ .api = .incremental, .quality = 0, .mode = "generic", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .one_shot, .quality = 0, .mode = "text", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .reusable, .quality = 0, .mode = "text", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .chunks, .quality = 0, .mode = "text", .hex = "00011042726f746c69207363686564756c656420580208626173656c696e653a206162636465666768616263646566676858626364656667685961626364656667683b2064696374696f6e61727920616e64206c69746572616c206d6f6465732e0a42b005000000d44d8f51150a21c06114c89e97942dd9860080ba79f55fa9360643eb310cc3300c1b43350c1f1fc330ccb13154c3300cc3300c00b68d3115b19b8c26465f95303954be5201c2a9954d0f406251f34038403700e829091b38419257f686e3076c02954b0716bc5d74eedb359a3f4830" },
    .{ .api = .incremental, .quality = 0, .mode = "text", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .one_shot, .quality = 0, .mode = "font", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .reusable, .quality = 0, .mode = "font", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .chunks, .quality = 0, .mode = "font", .hex = "00011042726f746c69207363686564756c656420580208626173656c696e653a206162636465666768616263646566676858626364656667685961626364656667683b2064696374696f6e61727920616e64206c69746572616c206d6f6465732e0a42b005000000d44d8f51150a21c06114c89e97942dd9860080ba79f55fa9360643eb310cc3300c1b43350c1f1fc330ccb13154c3300cc3300c00b68d3115b19b8c26465f95303954be5201c2a9954d0f406251f34038403700e829091b38419257f686e3076c02954b0716bc5d74eedb359a3f4830" },
    .{ .api = .incremental, .quality = 0, .mode = "font", .hex = "3011000000a89b1ea32a144280c328903d2f295bb20d01c07ff7efbf6bef3927514d727f0cfb8b1b0707070f1e9c399f443578f1e2c362b158c7a45fd562b1582c168b05087546a4a2340a87857692bd27f82eaed157254c0e95af5480706a65d3039058d43c8e07bf5df2e7e2f0cd2748f2cade70fc804da072e9c082b78bce7d8bff27d80d" },
    .{ .api = .one_shot, .quality = 1, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .reusable, .quality = 1, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .chunks, .quality = 1, .mode = "generic", .hex = "00011042726f746c69207363686564756c6564205802000000d5cd6354854208701805b2ff0a2c197bf2df001b7070e0100e8ce30950d25038149edac0524df7f3369ee235f97798d7e92dd97f300de1539d81af99c6ba1cb005000000d5cd635485420870180572ff0a5f32fe641f02d88083068770011c08478ee18e5b94458c74c3ac8dfa39154526dd3a3748a9cafb6992f184d798c10eb59a36bac40fe90ab76488e31dcab92e47fc5f1a" },
    .{ .api = .incremental, .quality = 1, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .one_shot, .quality = 1, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .reusable, .quality = 1, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .chunks, .quality = 1, .mode = "text", .hex = "00011042726f746c69207363686564756c6564205802000000d5cd6354854208701805b2ff0a2c197bf2df001b7070e0100e8ce30950d25038149edac0524df7f3369ee235f97798d7e92dd97f300de1539d81af99c6ba1cb005000000d5cd635485420870180572ff0a5f32fe641f02d88083068770011c08478ee18e5b94458c74c3ac8dfa39154526dd3a3748a9cafb6992f184d798c10eb59a36bac40fe90ab76488e31dcab92e47fc5f1a" },
    .{ .api = .incremental, .quality = 1, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .one_shot, .quality = 1, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .reusable, .quality = 1, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .chunks, .quality = 1, .mode = "font", .hex = "00011042726f746c69207363686564756c6564205802000000d5cd6354854208701805b2ff0a2c197bf2df001b7070e0100e8ce30950d25038149edac0524df7f3369ee235f97798d7e92dd97f300de1539d81af99c6ba1cb005000000d5cd635485420870180572ff0a5f32fe641f02d88083068770011c08478ee18e5b94458c74c3ac8dfa39154526dd3a3748a9cafb6992f184d798c10eb59a36bac40fe90ab76488e31dcab92e47fc5f1a" },
    .{ .api = .incremental, .quality = 1, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704e08483060ec383e33120ae014ac2348e39d20d511bf5732a8a04dd3a3748a9cafb698e27f18abc77a8d5b4d165fe90ae704b4e71bc4319ebf21fcc" },
    .{ .api = .one_shot, .quality = 2, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .reusable, .quality = 2, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .chunks, .quality = 2, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b60000400000007030164462920000b8d366506cfc01" },
    .{ .api = .incremental, .quality = 2, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .one_shot, .quality = 2, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .reusable, .quality = 2, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .chunks, .quality = 2, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b60000400000007030164462920000b8d366506cfc01" },
    .{ .api = .incremental, .quality = 2, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .one_shot, .quality = 2, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .reusable, .quality = 2, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .chunks, .quality = 2, .mode = "font", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b60000400000007030164462920000b8d366506cfc01" },
    .{ .api = .incremental, .quality = 2, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc9370400001c8c059198240000eeb44916c71ce986a88dfa391545826e9d1ba454e5fd3469b0a7b84be1b52cef50ab69a3cbfc215de1969ce2788732d6c5f803" },
    .{ .api = .one_shot, .quality = 3, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .reusable, .quality = 3, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .chunks, .quality = 3, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b600004000846081c57f" },
    .{ .api = .incremental, .quality = 3, .mode = "generic", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .one_shot, .quality = 3, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .reusable, .quality = 3, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .chunks, .quality = 3, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b600004000846081c57f" },
    .{ .api = .incremental, .quality = 3, .mode = "text", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .one_shot, .quality = 3, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .reusable, .quality = 3, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .chunks, .quality = 3, .mode = "font", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b600004000846081c57f" },
    .{ .api = .incremental, .quality = 3, .mode = "font", .hex = "3011000000aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d0a2b8e39d20d511bf5732a8a04dd3a3748a9cafb6938bde29677a8d5b4d165fe90ae704b4e71bc4319ebf21f" },
    .{ .api = .one_shot, .quality = 4, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 4, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 4, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 4, .mode = "generic", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 4, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 4, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 4, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 4, .mode = "text", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 4, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 4, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 4, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 4, .mode = "font", .hex = "3011001900aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9e5471cc916e88daa89f535124e8d6b9414a55de4fc3e9952def50ab69a3cbfc215de1969ce2788732d6e51d" },
    .{ .api = .one_shot, .quality = 5, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 5, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 5, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 5, .mode = "generic", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 5, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 5, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 5, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 5, .mode = "text", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 5, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 5, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 5, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 5, .mode = "font", .hex = "3011001900aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9e5471cc916e88daa89f535124e8d6b9414a55de4fc3e9952def50ab69a3cbfc215de1969ce2788732d6e51d" },
    .{ .api = .one_shot, .quality = 6, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 6, .mode = "generic", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 6, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 6, .mode = "generic", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 6, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 6, .mode = "text", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 6, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 6, .mode = "text", .hex = "3011003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9f5371cc916e88daa89f535124e8d6b9414a55de4fc3e9d52def50ab69a3cbfc215de1969ce2788732d66538" },
    .{ .api = .one_shot, .quality = 6, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .reusable, .quality = 6, .mode = "font", .hex = "6222003c00aa9bc7a80a8510e0300ae4fe15be64fcc93704dd88232669282f9f5371cc916e88daa89f535124e8d6b9414a55de4fc3c9ab5bdea156d34697f943bac22d39c5f10e65accb10" },
    .{ .api = .chunks, .quality = 6, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 6, .mode = "font", .hex = "3011001900aa9bc7a80a8510e0300ae4fe15be64fcc93704dd80232669281d9e5471cc916e88daa89f535124e8d6b9414a55de4fc3e9952def50ab69a3cbfc215de1969ce2788732d6e51d" },
    .{ .api = .one_shot, .quality = 7, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 7, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 7, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 7, .mode = "generic", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 7, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 7, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 7, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 7, .mode = "text", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 7, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 7, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 7, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 7, .mode = "font", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 8, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 8, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 8, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 8, .mode = "generic", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 8, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 8, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 8, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 8, .mode = "text", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 8, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 8, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 8, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 8, .mode = "font", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 9, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 9, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 9, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 9, .mode = "generic", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 9, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 9, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 9, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 9, .mode = "text", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 9, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 9, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 9, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 9, .mode = "font", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 10, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 10, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 10, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 10, .mode = "generic", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 10, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 10, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 10, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 10, .mode = "text", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 10, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 10, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 10, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 10, .mode = "font", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 11, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 11, .mode = "generic", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 11, .mode = "generic", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 11, .mode = "generic", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 11, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 11, .mode = "text", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 11, .mode = "text", .hex = "0001003c80722cf7b776ce99c52d1113ee9a0c9600800700db91271450205942856bffdd681b70c045bf51448b16a181434ef018c66d49c1071f6176c247625143173fbd9d7f38c1b4bc39219a90d41a07b6003043008460b1261e" },
    .{ .api = .incremental, .quality = 11, .mode = "text", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
    .{ .api = .one_shot, .quality = 11, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .reusable, .quality = 11, .mode = "font", .hex = "6222003c00cc0dbb251992a1d82c49232a6f636303800d0ed893e90c922c8e8003879c6018c6df92b2155ea624831c7c84c90ef77d2416fd168fd7e49f9b602a5a18604dc8e41c2d10" },
    .{ .api = .chunks, .quality = 11, .mode = "font", .hex = "0001001980722cf7b776ce99c52dc113ee8a064b00c00380edc8130a28902ca1c2b5ff6eb40d38e0a2df28a2458bd0c02127780ce3b6a4e0838f303be123b1a8a18b9fdece3f9c605ade9c104d486a8d035b0098210042b058130f" },
    .{ .api = .incremental, .quality = 11, .mode = "font", .hex = "3011000900cc0dbb251992a1d82c49232a6f636303800d0e685049b60c922c8e80030eb8382d89571e5be1651a36d0e219263bdcf79158709b87d6cca11f32152d0cb032323947f30f" },
};

pub const HeapLedger = struct {
    backing: std.mem.Allocator,
    limit: usize,
    live: usize = 0,
    peak: usize = 0,
    largest_request: usize = 0,
    denied_requests: usize = 0,
    force_moving_growth: bool = false,

    pub fn init(backing: std.mem.Allocator, limit: usize) HeapLedger {
        return .{ .backing = backing, .limit = limit };
    }

    pub fn allocator(self: *HeapLedger) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }

    fn permit(self: *HeapLedger, previous_len: usize, next_len: usize) bool {
        self.largest_request = @max(self.largest_request, next_len);
        const next_live = std.math.add(usize, self.live - previous_len, next_len) catch {
            self.denied_requests += 1;
            return false;
        };
        if (next_live > self.limit) {
            self.denied_requests += 1;
            return false;
        }
        return true;
    }

    fn update(self: *HeapLedger, previous_len: usize, next_len: usize) void {
        self.live = self.live - previous_len + next_len;
        self.peak = @max(self.peak, self.live);
    }

    fn alloc(context: *anyopaque, len: usize, alignment: std.mem.Alignment, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (!self.permit(0, len)) return null;
        const result = self.backing.rawAlloc(len, alignment, return_address) orelse return null;
        self.update(0, len);
        return result;
    }

    fn resize(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) bool {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (self.force_moving_growth) return false;
        if (!self.permit(memory.len, new_len)) return false;
        if (!self.backing.rawResize(memory, alignment, new_len, return_address)) return false;
        self.update(memory.len, new_len);
        return true;
    }

    fn remap(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, new_len: usize, return_address: usize) ?[*]u8 {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        if (self.force_moving_growth) return null;
        if (!self.permit(memory.len, new_len)) return null;
        const result = self.backing.rawRemap(memory, alignment, new_len, return_address) orelse return null;
        self.update(memory.len, new_len);
        return result;
    }

    fn free(context: *anyopaque, memory: []u8, alignment: std.mem.Alignment, return_address: usize) void {
        const self: *HeapLedger = @ptrCast(@alignCast(context));
        self.backing.rawFree(memory, alignment, return_address);
        self.update(memory.len, 0);
    }
};
