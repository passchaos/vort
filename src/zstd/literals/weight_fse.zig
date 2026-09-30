const std = @import("std");
pub const Error = error{ CorruptFrame, TruncatedFrame };

pub const ParseResult = struct {
    value_count: usize,
    table_len: usize,
    bytes_consumed: usize,
};

const ReservoirReader = struct {
    bytes: []const u8,
    reservoir: u64 = 0,
    available: u7 = 0,
    next_index: usize = 0,
    consumed_bits: usize = 0,

    fn init(bytes: []const u8) ReservoirReader {
        if (bytes.len < @sizeOf(u64)) return .{ .bytes = bytes };
        return .{
            .bytes = bytes,
            .reservoir = std.mem.readInt(u64, bytes[0..@sizeOf(u64)], .little),
            .available = 64,
            .next_index = @sizeOf(u64),
        };
    }

    inline fn read(self: *ReservoirReader, count: u4) Error!u16 {
        std.debug.assert(count != 0 and count <= 7);
        while (self.available < count) {
            if (self.next_index >= self.bytes.len) return error.TruncatedFrame;
            self.reservoir |= @as(u64, self.bytes[self.next_index]) << @intCast(self.available);
            self.available += 8;
            self.next_index += 1;
        }
        const value: u16 = @intCast(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.available -= count;
        self.consumed_bits += count;
        return value;
    }
};

/// Decode the normalized-count header of an FSE-compressed Huffman weight
/// stream. Zstd restricts this table to tableLog 5 or 6. Loading one reservoir
/// up front avoids reassembling the same neighboring bytes for every count.
pub inline fn parseNormalizedCounts(bytes: []const u8, values: []u16) Error!ParseResult {
    var reader = ReservoirReader.init(bytes);
    const accuracy_log_biased = try reader.read(4);
    if (accuracy_log_biased > 1) return error.CorruptFrame;
    const accuracy_log: u4 = @intCast(accuracy_log_biased + 5);

    const total_probability: u16 = @as(u16, 1) << accuracy_log;
    var accumulated_probability: u16 = 0;
    var value_count: usize = 0;
    while (accumulated_probability < total_probability) {
        const max_bits: u4 = @intCast(std.math.log2_int(u16, total_probability - accumulated_probability + 1) + 1);
        const small = try reader.read(max_bits - 1);
        const cutoff = (@as(u16, 1) << max_bits) - 1 - (total_probability - accumulated_probability + 1);
        const value = if (small < cutoff)
            small
        else value: {
            const value_read = small + ((try reader.read(1)) << (max_bits - 1));
            break :value if (value_read < @as(u16, 1) << (max_bits - 1))
                value_read
            else
                value_read - cutoff;
        };

        accumulated_probability += if (value != 0) value - 1 else 1;
        values[value_count] = value;
        value_count += 1;

        if (value == 1) {
            while (true) {
                const repeat_flag = try reader.read(2);
                if (repeat_flag + value_count > values.len) return error.CorruptFrame;
                for (0..repeat_flag) |_| {
                    values[value_count] = 1;
                    value_count += 1;
                }
                if (repeat_flag < 3) break;
            }
        }
        if (value_count == values.len) break;
    }

    if (value_count < 2 or accumulated_probability != total_probability)
        return error.CorruptFrame;
    return .{
        .value_count = value_count,
        .table_len = @as(usize, 1) << accuracy_log,
        .bytes_consumed = (reader.consumed_bits + 7) / 8,
    };
}

const ReferenceReader = struct {
    bytes: []const u8,
    bit_index: usize = 0,

    fn read(self: *ReferenceReader, count: u4) Error!u16 {
        if (self.bit_index + count > self.bytes.len * 8) return error.TruncatedFrame;
        var value: u16 = 0;
        for (0..count) |offset| {
            const index = self.bit_index + offset;
            value |= @as(u16, (self.bytes[index >> 3] >> @intCast(index & 7)) & 1) << @intCast(offset);
        }
        self.bit_index += count;
        return value;
    }
};

fn parseReference(bytes: []const u8, values: *[256]u16) Error!ParseResult {
    var reader: ReferenceReader = .{ .bytes = bytes };
    const accuracy_log_biased = try reader.read(4);
    if (accuracy_log_biased > 1) return error.CorruptFrame;
    const accuracy_log: u4 = @intCast(accuracy_log_biased + 5);
    const total_probability: u16 = @as(u16, 1) << accuracy_log;
    var accumulated_probability: u16 = 0;
    var value_count: usize = 0;
    while (accumulated_probability < total_probability) {
        const max_bits: u4 = @intCast(std.math.log2_int(u16, total_probability - accumulated_probability + 1) + 1);
        const small = try reader.read(max_bits - 1);
        const cutoff = (@as(u16, 1) << max_bits) - 1 - (total_probability - accumulated_probability + 1);
        const value = if (small < cutoff)
            small
        else value: {
            const value_read = small + ((try reader.read(1)) << (max_bits - 1));
            break :value if (value_read < @as(u16, 1) << (max_bits - 1)) value_read else value_read - cutoff;
        };
        accumulated_probability += if (value != 0) value - 1 else 1;
        values[value_count] = value;
        value_count += 1;
        if (value == 1) {
            while (true) {
                const repeat_flag = try reader.read(2);
                if (repeat_flag + value_count > values.len) return error.CorruptFrame;
                for (0..repeat_flag) |_| {
                    values[value_count] = 1;
                    value_count += 1;
                }
                if (repeat_flag < 3) break;
            }
        }
        if (value_count == values.len) break;
    }
    if (value_count < 2 or accumulated_probability != total_probability) return error.CorruptFrame;
    return .{
        .value_count = value_count,
        .table_len = @as(usize, 1) << accuracy_log,
        .bytes_consumed = (reader.bit_index + 7) / 8,
    };
}

test "Huffman weight normalized-count reservoir matches bit oracle" {
    var state: u64 = 0x243f_6a88_85a3_08d3;
    var successes: usize = 0;
    for (1..33) |len| {
        for (0..2048) |_| {
            var bytes: [32]u8 = undefined;
            for (bytes[0..len]) |*byte| {
                state = state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
                byte.* = @truncate(state >> 32);
            }
            var expected_values: [256]u16 = undefined;
            var actual_values: [256]u16 = undefined;
            const expected = parseReference(bytes[0..len], &expected_values) catch |expected_error| {
                try std.testing.expectError(expected_error, parseNormalizedCounts(bytes[0..len], &actual_values));
                continue;
            };
            const actual = try parseNormalizedCounts(bytes[0..len], &actual_values);
            try std.testing.expectEqual(expected, actual);
            try std.testing.expectEqualSlices(u16, expected_values[0..expected.value_count], actual_values[0..actual.value_count]);
            successes += 1;
        }
    }
    try std.testing.expect(successes > 100);
}

pub fn expectMatchesGeneric(comptime parse_generic: anytype) !void {
    var random_state: u64 = 0x1319_8a2e_0370_7344;
    var accepted: usize = 0;
    for (1..33) |len| {
        for (0..1024) |_| {
            var bytes: [32]u8 = undefined;
            for (bytes[0..len]) |*byte| {
                random_state = random_state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
                byte.* = @truncate(random_state >> 32);
            }

            var expected_values: [256]u16 = undefined;
            const expected_result = parse_generic(bytes[0..len], &expected_values);
            var actual_values: [256]u16 = undefined;
            const actual_result = parseNormalizedCounts(bytes[0..len], &actual_values);
            if (expected_result) |expected| {
                const actual = try actual_result;
                try std.testing.expectEqual(expected, actual);
                try std.testing.expectEqualSlices(
                    u16,
                    expected_values[0..expected.value_count],
                    actual_values[0..actual.value_count],
                );
                accepted += 1;
            } else |expected_error| {
                try std.testing.expectError(expected_error, actual_result);
            }
        }
    }
    try std.testing.expect(accepted > 50);
}
