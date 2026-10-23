const std = @import("std");
const format = @import("../format.zig");
const options = @import("../encode_options.zig");
const block_plan = @import("block_plan.zig");
const fse = @import("fse.zig");
const bit_writer = @import("bit_writer.zig");
const header_writer = @import("header.zig");

pub const Block = struct {
    bytes: []u8,
    literal_payload_size: usize,
    lmd_payload_size: usize,

    pub fn deinit(self: *Block, allocator: std.mem.Allocator) void {
        allocator.free(self.bytes);
        self.* = undefined;
    }
};

/// A block owns its complete header and payload. Plans and input history remain
/// unchanged, including their real distances; repeat-distance zeroes are local
/// wire values and reset at each block boundary.
pub fn encodePlanAlloc(allocator: std.mem.Allocator, plan: *const block_plan.Plan, version: options.FseVersion) !Block {
    try plan.validate();
    const padding = (4 - plan.literals.items.len % 4) % 4;
    const literal_count = plan.literals.items.len + padding;
    if (literal_count > format.max_literal_count or plan.records.items.len > format.max_match_count or
        plan.raw_size > std.math.maxInt(u32)) return error.InvalidLzfseStream;

    var l_counts: [format.l_symbol_count]u32 = @splat(0);
    var m_counts: [format.m_symbol_count]u32 = @splat(0);
    var d_counts: [format.d_symbol_count]u32 = @splat(0);
    var literal_counts: [format.literal_symbol_count]u32 = @splat(0);
    var previous_distance: u32 = 0;
    for (plan.records.items) |record| {
        l_counts[try fse.valueSlot(record.literal_len, &format.l_base_value, &format.l_extra_bits)] += 1;
        m_counts[try fse.valueSlot(record.match_len, &format.m_base_value, &format.m_extra_bits)] += 1;
        const distance = if (record.distance == previous_distance) 0 else record.distance;
        d_counts[try fse.valueSlot(distance, &format.d_base_value, &format.d_extra_bits)] += 1;
        previous_distance = record.distance;
    }
    for (plan.literals.items) |byte| literal_counts[byte] += 1;
    literal_counts[0] += @intCast(padding);

    var header = format.CompressedHeader{
        .header_size = 0,
        .raw_size = plan.raw_size,
        .literal_count = literal_count,
        .match_count = plan.records.items.len,
        .literal_payload_size = 0,
        .lmd_payload_size = 0,
        .literal_bits = 0,
        .literal_states = @splat(0),
        .lmd_bits = 0,
        .l_state = 0,
        .m_state = 0,
        .d_state = 0,
        .l_frequencies = undefined,
        .m_frequencies = undefined,
        .d_frequencies = undefined,
        .literal_frequencies = undefined,
    };
    try fse.normalize(format.l_state_count, &l_counts, &header.l_frequencies);
    try fse.normalize(format.m_state_count, &m_counts, &header.m_frequencies);
    try fse.normalize(format.d_state_count, &d_counts, &header.d_frequencies);
    try fse.normalize(format.literal_state_count, &literal_counts, &header.literal_frequencies);
    var l_entries: [format.l_symbol_count]fse.Entry = undefined;
    var m_entries: [format.m_symbol_count]fse.Entry = undefined;
    var d_entries: [format.d_symbol_count]fse.Entry = undefined;
    var literal_entries: [format.literal_symbol_count]fse.Entry = undefined;
    const l_table = try fse.initTable(format.l_state_count, &header.l_frequencies, &l_entries);
    const m_table = try fse.initTable(format.m_state_count, &header.m_frequencies, &m_entries);
    const d_table = try fse.initTable(format.d_state_count, &header.d_frequencies, &d_entries);
    const literal_table = try fse.initTable(format.literal_state_count, &header.literal_frequencies, &literal_entries);

    var literal_writer = bit_writer.Writer{};
    defer literal_writer.deinit(allocator);
    var index = literal_count;
    while (index != 0) {
        index -= 1;
        const byte = if (index < plan.literals.items.len) plan.literals.items[index] else 0;
        try literal_table.encodeSymbol(allocator, &header.literal_states[index % 4], &literal_writer, byte);
    }
    header.literal_bits = try literal_writer.finish(allocator);
    header.literal_payload_size = literal_writer.bytes.items.len;

    var lmd_writer = bit_writer.Writer{};
    defer lmd_writer.deinit(allocator);
    // The Apple decoder initializes its reverse reader within this payload.
    // This prefix permits its eight-byte look-behind even for zero-bit states.
    try lmd_writer.bytes.appendNTimes(allocator, 0, 8);
    index = plan.records.items.len;
    while (index != 0) {
        index -= 1;
        const record = plan.records.items[index];
        const previous = if (index == 0) 0 else plan.records.items[index - 1].distance;
        const distance = if (record.distance == previous) 0 else record.distance;
        try d_table.encodeValue(allocator, &header.d_state, &lmd_writer, distance, &format.d_base_value, &format.d_extra_bits);
        try m_table.encodeValue(allocator, &header.m_state, &lmd_writer, record.match_len, &format.m_base_value, &format.m_extra_bits);
        try l_table.encodeValue(allocator, &header.l_state, &lmd_writer, record.literal_len, &format.l_base_value, &format.l_extra_bits);
    }
    header.lmd_bits = try lmd_writer.finish(allocator);
    header.lmd_payload_size = lmd_writer.bytes.items.len;

    const header_bytes = try header_writer.encodeAlloc(allocator, header, version);
    defer allocator.free(header_bytes);
    const payload_size = try header.payloadSize();
    const total_size = std.math.add(usize, header_bytes.len, payload_size) catch return error.IntegerOverflow;
    const output = try allocator.alloc(u8, total_size);
    @memcpy(output[0..header_bytes.len], header_bytes);
    const lmd_start = header_bytes.len + header.literal_payload_size;
    @memcpy(output[header_bytes.len..lmd_start], literal_writer.bytes.items);
    @memcpy(output[lmd_start..], lmd_writer.bytes.items);
    return .{ .bytes = output, .literal_payload_size = header.literal_payload_size, .lmd_payload_size = header.lmd_payload_size };
}

fn expectDecoded(plan: *const block_plan.Plan, block: Block, expected: []const u8, history_size: usize) !format.CompressedHeader {
    const decoder = @import("../decoder.zig");
    const fse_decoder = @import("../fse.zig");
    const allocator = std.testing.allocator;
    const header = try format.parseCompressedHeader(block.bytes);
    const literal_end = header.header_size + header.literal_payload_size;
    const literal_payload = block.bytes[header.header_size..literal_end];
    const lmd_payload = block.bytes[literal_end..];
    try std.testing.expectEqualSlices(u8, &(@as([8]u8, @splat(0))), lmd_payload[0..8]);
    const output = try allocator.alloc(u8, expected.len);
    defer allocator.free(output);
    @memcpy(output[0..history_size], expected[0..history_size]);
    try std.testing.expectEqual(plan.raw_size, try decoder.decodePayloadInto(header, literal_payload, lmd_payload, output, history_size));
    try std.testing.expectEqualSlices(u8, expected, output);

    var literal_entries: [format.literal_state_count]fse_decoder.DecoderEntry = undefined;
    try fse_decoder.initDecoderTable(format.literal_state_count, &header.literal_frequencies, &literal_entries);
    var literal_states = header.literal_states;
    var reader = try fse_decoder.BitReader.init(literal_payload, header.literal_bits);
    for (0..header.literal_count) |index| {
        const expected_byte = if (index < plan.literals.items.len) plan.literals.items[index] else 0;
        try std.testing.expectEqual(expected_byte, try fse_decoder.decodeSymbol(&literal_states[index % 4], &literal_entries, &reader));
    }
    try std.testing.expectEqualDeep(@as([4]u16, @splat(0)), literal_states);
    try std.testing.expectEqual(@as(usize, 0), reader.bit_position);
    var l_entries: [format.l_state_count]fse_decoder.ValueDecoderEntry = undefined;
    var m_entries: [format.m_state_count]fse_decoder.ValueDecoderEntry = undefined;
    var d_entries: [format.d_state_count]fse_decoder.ValueDecoderEntry = undefined;
    try fse_decoder.initValueDecoderTable(format.l_state_count, &header.l_frequencies, &format.l_extra_bits, &format.l_base_value, &l_entries);
    try fse_decoder.initValueDecoderTable(format.m_state_count, &header.m_frequencies, &format.m_extra_bits, &format.m_base_value, &m_entries);
    try fse_decoder.initValueDecoderTable(format.d_state_count, &header.d_frequencies, &format.d_extra_bits, &format.d_base_value, &d_entries);
    var states = [_]u16{ header.l_state, header.m_state, header.d_state };
    reader = try fse_decoder.BitReader.init(lmd_payload, header.lmd_bits);
    var previous_distance: u32 = 0;
    for (plan.records.items) |record| {
        try std.testing.expectEqual(@as(i32, record.literal_len), try fse_decoder.decodeValue(&states[0], &l_entries, &reader));
        try std.testing.expectEqual(@as(i32, record.match_len), try fse_decoder.decodeValue(&states[1], &m_entries, &reader));
        const distance = if (record.distance == previous_distance) 0 else record.distance;
        try std.testing.expectEqual(@as(i32, @intCast(distance)), try fse_decoder.decodeValue(&states[2], &d_entries, &reader));
        previous_distance = record.distance;
    }
    try std.testing.expectEqualDeep(@as([3]u16, @splat(0)), states);
    try std.testing.expectEqual(@as(usize, 64), reader.bit_position);
    return header;
}

test "LZFSE encoder blocks compress overlapping maximum-length matches with zero-byte literals" {
    const allocator = std.testing.allocator;
    var plan = block_plan.Plan.init(0);
    defer plan.deinit(allocator);
    try plan.append(allocator, &.{0}, 99999, 1);
    const records = try allocator.dupe(block_plan.Record, plan.records.items);
    defer allocator.free(records);
    const expected = try allocator.alloc(u8, 100000);
    defer allocator.free(expected);
    @memset(expected, 0);
    for ([_]options.FseVersion{ .v1, .v2 }) |version| {
        var block = try encodePlanAlloc(allocator, &plan, version);
        defer block.deinit(allocator);
        const header = try expectDecoded(&plan, block, expected, 0);
        try std.testing.expectEqual(@as(usize, 4), header.literal_count);
        try std.testing.expectEqual(@as(usize, 0), block.literal_payload_size);
        try std.testing.expect(block.bytes.len < 1024);
        try std.testing.expectEqualDeep(records, plan.records.items);
        try std.testing.expectEqualSlices(u8, &.{0}, plan.literals.items);
    }
}

test "LZFSE encoder blocks preserve all literal lanes tails and empty literal histograms" {
    const allocator = std.testing.allocator;
    for (1..9) |size| {
        var plan = block_plan.Plan.init(0);
        defer plan.deinit(allocator);
        const input = "abcdefgh"[0..size];
        try plan.appendLiterals(allocator, input);
        for ([_]options.FseVersion{ .v1, .v2 }) |version| {
            var block = try encodePlanAlloc(allocator, &plan, version);
            defer block.deinit(allocator);
            const header = try expectDecoded(&plan, block, input, 0);
            try std.testing.expectEqual(std.mem.alignForward(usize, size, 4), header.literal_count);
        }
    }
    var plan = block_plan.Plan.init(1);
    defer plan.deinit(allocator);
    try plan.append(allocator, "", 7077, 1);
    const expected: [7078]u8 = @splat('q');
    var block = try encodePlanAlloc(allocator, &plan, .v2);
    defer block.deinit(allocator);
    const header = try expectDecoded(&plan, block, &expected, 1);
    try std.testing.expectEqual(@as(usize, 0), header.literal_count);
    try std.testing.expectEqual(@as(u16, 1024), header.literal_frequencies[0]);
}

test "LZFSE encoder blocks round trip all value slots with maximum cross-block distances" {
    const allocator = std.testing.allocator;
    const history_size = 262400;
    var plan = block_plan.Plan.init(history_size);
    defer plan.deinit(allocator);
    var expected: std.ArrayList(u8) = .empty;
    defer expected.deinit(allocator);
    try expected.resize(allocator, history_size);
    for (expected.items, 0..) |*byte, index| byte.* = @truncate(index);
    var literal: [315]u8 = undefined;
    for (0..64) |index| {
        const symbol = index % format.l_symbol_count;
        var literal_len: usize = @as(usize, @intCast(format.l_base_value[symbol])) + (@as(usize, 1) << @intCast(format.l_extra_bits[symbol])) - 1;
        const match_len: usize = @as(usize, @intCast(format.m_base_value[symbol])) + (@as(usize, 1) << @intCast(format.m_extra_bits[symbol])) - 1;
        const distance: u32 = if (index < 2) 1 else @as(u32, @intCast(format.d_base_value[index])) + (@as(u32, 1) << @intCast(format.d_extra_bits[index])) - 1;
        if (literal_len == 0 and match_len == 0) literal_len = 1;
        for (literal[0..literal_len], 0..) |*byte, offset| byte.* = @truncate(offset * 73 + index);
        try plan.append(allocator, literal[0..literal_len], match_len, if (match_len == 0) 1 else distance);
        try expected.appendSlice(allocator, literal[0..literal_len]);
        for (0..match_len) |_| try expected.append(allocator, expected.items[expected.items.len - distance]);
    }
    for ([_]options.FseVersion{ .v1, .v2 }) |version| {
        var block = try encodePlanAlloc(allocator, &plan, version);
        defer block.deinit(allocator);
        _ = try expectDecoded(&plan, block, expected.items, history_size);
    }
}

fn blockAllocationFailure(allocator: std.mem.Allocator, version: options.FseVersion) !void {
    var plan = block_plan.Plan.init(0);
    defer plan.deinit(allocator);
    try plan.append(allocator, "abcdefghijklmnopqrst" ** 32, 6000, 20);
    var block = try encodePlanAlloc(allocator, &plan, version);
    defer block.deinit(allocator);
    _ = try format.parseCompressedHeader(block.bytes);
    try plan.validate();
}

test "LZFSE encoder blocks release every payload and header allocation on failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, blockAllocationFailure, .{options.FseVersion.v1});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, blockAllocationFailure, .{options.FseVersion.v2});
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{ .fail_index = 0 });
    const empty = block_plan.Plan.init(0);
    try std.testing.expectError(error.InvalidLzfseStream, encodePlanAlloc(failing.allocator(), &empty, .v2));
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}
