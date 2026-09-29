const std = @import("std");
const builtin = @import("builtin");

pub const Error = error{ CorruptFrame, TruncatedFrame };

pub const Result = struct {
    value_count: usize,
    table_len: usize,
    bytes_consumed: usize,
};

const text_section = switch (builtin.object_format) {
    .elf => ".vort_zstd_fse_counts",
    .macho => "__TEXT,__vort_zstd_fc",
    .coff => ".text$vort_zstd_fse_counts",
    else => ".text",
};

const ReservoirReader = struct {
    bytes: []const u8,
    reservoir: u64 = 0,
    available: u7 = 0,
    next_index: usize = 0,

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
        std.debug.assert(count != 0 and count <= 9);
        while (self.available < count) {
            if (self.next_index >= self.bytes.len) return error.TruncatedFrame;
            self.reservoir |= @as(u64, self.bytes[self.next_index]) << @intCast(self.available);
            self.available += 8;
            self.next_index += 1;
        }
        const value: u16 = @intCast(self.reservoir & ((@as(u64, 1) << count) - 1));
        self.reservoir >>= count;
        self.available -= count;
        return value;
    }
};

/// Decode one byte-aligned Zstd FSE normalized-count description. Sequence
/// tables allow table logs through nine, so one count consumes at most nine
/// bits. A persistent little-endian reservoir avoids reconstructing adjacent
/// bytes for every field while exact consumed-bit accounting preserves the
/// caller's sequence-bitstream boundary.
pub noinline fn parse(
    bytes: []const u8,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
    values: *[256]u16,
) linksection(text_section) Error!Result {
    var reader = ReservoirReader.init(bytes);
    const accuracy_log_biased = try reader.read(4);
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.CorruptFrame;
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

    if (value_count < 2 or accumulated_probability != total_probability or value_count > expected_symbol_count)
        return error.CorruptFrame;
    return .{
        .value_count = value_count,
        .table_len = @as(usize, 1) << accuracy_log,
        .bytes_consumed = reader.next_index - reader.available / 8,
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

fn parseReference(
    bytes: []const u8,
    expected_symbol_count: usize,
    max_accuracy_log: u4,
    values: *[256]u16,
) Error!Result {
    var reader: ReferenceReader = .{ .bytes = bytes };
    const accuracy_log_biased = try reader.read(4);
    if (accuracy_log_biased > max_accuracy_log -| 5) return error.CorruptFrame;
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
    if (value_count < 2 or accumulated_probability != total_probability or value_count > expected_symbol_count)
        return error.CorruptFrame;
    return .{
        .value_count = value_count,
        .table_len = @as(usize, 1) << accuracy_log,
        .bytes_consumed = (reader.bit_index + 7) / 8,
    };
}

test "sequence normalized-count reservoir matches bit oracle" {
    var random_state: u64 = 0x243f_6a88_85a3_08d3;
    var successes: usize = 0;
    for (1..65) |len| {
        for (0..512) |_| {
            var bytes: [64]u8 = undefined;
            for (bytes[0..len]) |*byte| {
                random_state = random_state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
                byte.* = @truncate(random_state >> 32);
            }
            const limits_cases = [_]struct { usize, u4 }{
                .{ 32, 8 },
                .{ 36, 9 },
                .{ 53, 9 },
            };
            for (limits_cases) |limits| {
                var expected_values: [256]u16 = undefined;
                var actual_values: [256]u16 = undefined;
                const expected = parseReference(bytes[0..len], limits[0], limits[1], &expected_values) catch |expected_error| {
                    try std.testing.expectError(expected_error, parse(bytes[0..len], limits[0], limits[1], &actual_values));
                    continue;
                };
                const actual = try parse(bytes[0..len], limits[0], limits[1], &actual_values);
                try std.testing.expectEqual(expected, actual);
                try std.testing.expectEqualSlices(u16, expected_values[0..expected.value_count], actual_values[0..actual.value_count]);
                successes += 1;
            }
        }
    }
    try std.testing.expect(successes > 100);
}

pub fn expectMatchesGeneric(comptime parse_generic: anytype) !void {
    var random_state: u64 = 0x1319_8a2e_0370_7344;
    var accepted: usize = 0;
    for (1..65) |len| {
        for (0..256) |_| {
            var bytes: [64]u8 = undefined;
            for (bytes[0..len]) |*byte| {
                random_state = random_state *% 6_364_136_223_846_793_005 +% 1_442_695_040_888_963_407;
                byte.* = @truncate(random_state >> 32);
            }
            const limits_cases = [_]struct { usize, u4 }{
                .{ 32, 8 },
                .{ 36, 9 },
                .{ 53, 9 },
            };
            for (limits_cases) |limits| {
                var expected_values: [256]u16 = undefined;
                var actual_values: [256]u16 = undefined;
                const expected = parse_generic(bytes[0..len], limits[0], limits[1], &expected_values) catch |expected_error| {
                    try std.testing.expectError(expected_error, parse(bytes[0..len], limits[0], limits[1], &actual_values));
                    continue;
                };
                const actual = try parse(bytes[0..len], limits[0], limits[1], &actual_values);
                try std.testing.expectEqual(expected, actual);
                try std.testing.expectEqualSlices(u16, expected_values[0..expected.value_count], actual_values[0..actual.value_count]);
                accepted += 1;
            }
        }
    }
    try std.testing.expect(accepted > 100);
}
