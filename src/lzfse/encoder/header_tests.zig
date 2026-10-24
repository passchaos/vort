const std = @import("std");
const writer = @import("header.zig");
const format = @import("../format.zig");
const options = @import("../encode_options.zig");
const allocator = std.testing.allocator;

pub fn sampleHeader() format.CompressedHeader {
    var header = format.CompressedHeader{
        .header_size = 0,
        .raw_size = 4,
        .literal_count = 4,
        .match_count = 1,
        .literal_payload_size = 0,
        .lmd_payload_size = 8,
        .literal_bits = 0,
        .literal_states = @splat(0),
        .lmd_bits = 0,
        .l_state = 0,
        .m_state = 0,
        .d_state = 0,
        .l_frequencies = @splat(0),
        .m_frequencies = @splat(0),
        .d_frequencies = @splat(0),
        .literal_frequencies = @splat(0),
    };
    header.l_frequencies[0] = format.l_state_count;
    header.m_frequencies[0] = format.m_state_count;
    header.d_frequencies[0] = format.d_state_count;
    header.literal_frequencies[0] = format.literal_state_count;
    return header;
}

test "LZFSE encoder headers round trip every literal frequency from zero through 1024" {
    for (0..1025) |frequency| {
        var header = sampleHeader();
        header.literal_frequencies[0] = @intCast(frequency);
        header.literal_frequencies[1] = @intCast(1024 - frequency);
        for ([_]options.FseVersion{ .v1, .v2 }) |version| {
            const bytes = try writer.encodeAlloc(allocator, header, version);
            defer allocator.free(bytes);
            var expected = header;
            expected.header_size = bytes.len;
            try std.testing.expectEqualDeep(expected, try format.parseCompressedHeader(bytes));
            if (version == .v1) {
                try std.testing.expectEqual(@as(usize, 772), bytes.len);
                try std.testing.expectEqualSlices(u8, &.{ 0, 0 }, bytes[770..]);
            } else {
                try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, bytes[8..16], .little) >> 63);
                try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, bytes[16..24], .little) >> 63);
                try std.testing.expectEqual(@as(u64, 0), std.mem.readInt(u64, bytes[24..32], .little) >> 62);
            }
        }
    }
    try std.testing.expectError(error.InvalidLzfseStream, writer.frequencyCode(1025));
}

test "LZFSE encoder headers preserve field endpoints and all final bit counts" {
    for (0..8) |padding| {
        var header = sampleHeader();
        header.raw_size = std.math.maxInt(u32);
        header.literal_count = format.max_literal_count;
        header.match_count = format.max_match_count;
        header.literal_payload_size = (@as(usize, 1) << 20) - 1;
        header.lmd_payload_size = (@as(usize, 1) << 20) - 1;
        header.literal_bits = -@as(i8, @intCast(padding));
        header.lmd_bits = -@as(i8, @intCast(padding));
        header.literal_states = .{ 0, 1, 512, 1023 };
        header.l_state = 63;
        header.m_state = 63;
        header.d_state = 255;
        for ([_]options.FseVersion{ .v1, .v2 }) |version| {
            const bytes = try writer.encodeAlloc(allocator, header, version);
            defer allocator.free(bytes);
            var expected = header;
            expected.header_size = bytes.len;
            try std.testing.expectEqualDeep(expected, try format.parseCompressedHeader(bytes));
        }
    }
}

test "LZFSE encoder header validation rejects invalid fields before allocation" {
    var failing = std.testing.FailingAllocator.init(allocator, .{ .fail_index = 0 });
    for (0..11) |case| {
        var header = sampleHeader();
        switch (case) {
            0 => header.literal_count = 3,
            1 => header.literal_count = format.max_literal_count + 4,
            2 => header.match_count = format.max_match_count + 1,
            3 => header.literal_bits = -8,
            4 => header.lmd_bits = 1,
            5 => header.literal_states[3] = 1024,
            6 => header.l_state = 64,
            7 => header.m_state = 64,
            8 => header.d_state = 256,
            9 => header.l_frequencies[0] -= 1,
            10 => header.literal_payload_size = @as(usize, 1) << 20,
            else => unreachable,
        }
        try std.testing.expectError(error.InvalidLzfseStream, writer.encodeAlloc(failing.allocator(), header, .v2));
    }
    try std.testing.expectEqual(@as(usize, 0), failing.alloc_index);
}

fn allocationFailure(test_allocator: std.mem.Allocator, version: options.FseVersion) !void {
    const bytes = try writer.encodeAlloc(test_allocator, sampleHeader(), version);
    defer test_allocator.free(bytes);
    _ = try format.parseCompressedHeader(bytes);
}

test "LZFSE encoder headers clean up every allocation failure" {
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{options.FseVersion.v1});
    try std.testing.checkAllAllocationFailures(allocator, allocationFailure, .{options.FseVersion.v2});
}
